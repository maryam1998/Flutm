package com.linglearn.app.overlay;

import android.content.Context;
import android.media.AudioFormat;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.util.Log;

import com.k2fsa.sherpa.onnx.FeatureConfig;
import com.k2fsa.sherpa.onnx.OfflineModelConfig;
import com.k2fsa.sherpa.onnx.OfflineRecognizer;
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig;
import com.k2fsa.sherpa.onnx.OfflineStream;
import com.k2fsa.sherpa.onnx.OfflineWhisperModelConfig;

import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.ShortBuffer;

/**
 * همگام‌سازیِ متنِ داستان با «صوتِ آپلودیِ کاربر» — سمتِ نیتیو.
 *
 * فایلِ صوتی با MediaCodec به PCM تک‌کاناله ۱۶کیلوهرتز دیکود می‌شه (جریانی؛ کلِ فایل توی RAM نمی‌مونه)،
 * روی نقطه‌های سکوت به پنجره‌ها بریده می‌شه و هر پنجره با Whisper (همون بسته‌های «آهنگ‌ها») رونویسی می‌شه.
 * به‌محضِ تمام‌شدنِ هر پنجره، متن + زمانِ شروع/پایانش با رویدادِ syncChunk به دارت می‌رسه،
 * تا هر مقدار که همگام شد همون لحظه توی اپ اجرا بشه و کاربر منتظرِ پایانِ کلِ فایل نمونه.
 *
 * ⚠️ از timestampِ توکن‌های Whisper استفاده نمی‌کنیم (نسخه‌ی sherpa ممکنه نداشته باشه)؛
 * زمانِ هر پنجره از روی موقعیتِ نمونه‌ها دقیقاً معلومه و دارت کلمه‌ها رو داخلِ پنجره پخش می‌کنه.
 */
final class AudioSyncTranscriber {

    private static final String TAG = "AudioSync";
    private static final int SR = 16000;
    private static final int FRAME = SR / 10;              // ۱۰۰ms

    // پنجره‌ی اول کوتاه (تا زودتر نتیجه بیاد)، بعدی‌ها بلندتر (Whisper همیشه ۳۰ثانیه پردازش می‌کنه؛ پنجره‌ی بلند = سریع‌تر)
    private static final int FIRST_MIN = 6 * SR;
    private static final int FIRST_MAX = 12 * SR;
    private static final int NEXT_MIN = 14 * SR;
    private static final int NEXT_MAX = 26 * SR;
    private static final int SEARCH_BACK = 5 * SR;
    private static final double SILENT_RMS = 0.004;

    interface Listener {
        /** text: متنِ پنجره؛ start/end: ثانیه روی خطِ زمانیِ فایل؛ frac: ۰..۱ پیشرفتِ کل. */
        void onChunk(String job, String text, double start, double end, double frac);
        void onDone(String job);
        void onError(String job, String code, String message);
    }

    private AudioSyncTranscriber() {}

    private static final Object LOCK = new Object();
    private static Job current = null;

    static void start(Context ctx, String job, String path, String lang, String model, Listener l) {
        synchronized (LOCK) {
            if (current != null) current.cancel = true;     // کارِ قبلی متوقف می‌شه
            Job j = new Job(ctx, job, path, lang, model, l);
            current = j;
            Thread t = new Thread(j, "audio-sync");
            t.setDaemon(true);
            t.start();
        }
    }

    static void cancel() {
        synchronized (LOCK) {
            if (current != null) current.cancel = true;
        }
    }

    // ------------------------------------------------------------------

    private static final class Job implements Runnable {
        final Context ctx;
        final String id, path, lang, model;
        final Listener l;
        volatile boolean cancel = false;

        OfflineRecognizer rec;
        double durationSec = 0;
        boolean first = true;
        String lastText = "";

        // بافرِ پنجره
        final float[] buf = new float[NEXT_MAX + SR];
        int len = 0;
        long base = 0;               // تعدادِ نمونه‌های قبل از buf[0]
        double sumSq = 0;
        int sinceCheck = 0;
        long emitted = 0;            // کلِ نمونه‌های ۱۶k تا الان

        // resampler (میانگین‌گیریِ مساحتی؛ بدونِ aliasing محسوس)
        double ratio = 1;            // نمونه‌ی ورودی به ازای هر نمونه‌ی خروجی
        double binFill = 0;
        double acc = 0;

        Job(Context ctx, String id, String path, String lang, String model, Listener l) {
            this.ctx = ctx; this.id = id; this.path = path; this.lang = lang; this.model = model; this.l = l;
        }

        @Override
        public void run() {
            MediaExtractor ex = null;
            MediaCodec codec = null;
            try {
                File dir = WhisperModelManager.getModelDir(ctx, model);
                if (dir == null) { l.onError(id, "NO_MODEL", "model not downloaded"); return; }
                rec = createRecognizer(dir);
                if (rec == null) { l.onError(id, "ENGINE", "cannot load whisper"); return; }

                ex = new MediaExtractor();
                ex.setDataSource(path);
                int track = -1;
                MediaFormat fmt = null;
                String mime = null;
                for (int i = 0; i < ex.getTrackCount(); i++) {
                    MediaFormat f = ex.getTrackFormat(i);
                    String m = f.getString(MediaFormat.KEY_MIME);
                    if (m != null && m.startsWith("audio/")) { track = i; fmt = f; mime = m; break; }
                }
                if (track < 0) { l.onError(id, "NO_AUDIO", "no audio track"); return; }
                ex.selectTrack(track);
                if (fmt.containsKey(MediaFormat.KEY_DURATION)) {
                    durationSec = fmt.getLong(MediaFormat.KEY_DURATION) / 1_000_000.0;
                }

                codec = MediaCodec.createDecoderByType(mime);
                codec.configure(fmt, null, null, 0);
                codec.start();

                int inRate = fmt.containsKey(MediaFormat.KEY_SAMPLE_RATE) ? fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE) : SR;
                int ch = fmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT) ? fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 1;
                boolean floatPcm = false;
                setRate(inRate);

                MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
                boolean inEos = false, outEos = false;
                while (!outEos && !cancel) {
                    if (!inEos) {
                        int ii = codec.dequeueInputBuffer(10_000);
                        if (ii >= 0) {
                            ByteBuffer ib = codec.getInputBuffer(ii);
                            int n = ib == null ? -1 : ex.readSampleData(ib, 0);
                            if (n < 0) {
                                codec.queueInputBuffer(ii, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                                inEos = true;
                            } else {
                                codec.queueInputBuffer(ii, 0, n, ex.getSampleTime(), 0);
                                ex.advance();
                            }
                        }
                    }
                    int oi = codec.dequeueOutputBuffer(info, 10_000);
                    if (oi >= 0) {
                        ByteBuffer ob = codec.getOutputBuffer(oi);
                        if (info.size > 0 && ob != null) {
                            ob.position(info.offset);
                            ob.limit(info.offset + info.size);
                            ob.order(ByteOrder.nativeOrder());
                            consume(ob, ch, floatPcm);
                        }
                        codec.releaseOutputBuffer(oi, false);
                        if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) outEos = true;
                    } else if (oi == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        MediaFormat of = codec.getOutputFormat();
                        if (of.containsKey(MediaFormat.KEY_SAMPLE_RATE)) setRate(of.getInteger(MediaFormat.KEY_SAMPLE_RATE));
                        if (of.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) ch = of.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                        floatPcm = of.containsKey(MediaFormat.KEY_PCM_ENCODING)
                                && of.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT;
                    }
                }
                if (cancel) return;
                // ته‌مانده‌ی صدا
                if (len >= SR / 2) cut(len);
                if (!cancel) l.onDone(id);
            } catch (Throwable e) {
                Log.e(TAG, "sync failed", e);
                if (!cancel) l.onError(id, "FAILED", String.valueOf(e.getMessage()));
            } finally {
                try { if (codec != null) { codec.stop(); codec.release(); } } catch (Throwable ignored) {}
                try { if (ex != null) ex.release(); } catch (Throwable ignored) {}
                try { if (rec != null) rec.release(); } catch (Throwable ignored) {}
                synchronized (LOCK) { if (current == this) current = null; }
            }
        }

        // ---------------- موتور ----------------
        private OfflineRecognizer createRecognizer(File dir) {
            try {
                String lg = SherpaModelManager.normalize(lang);
                if (lg == null || "auto".equals(lg)) lg = "";

                OfflineWhisperModelConfig w = new OfflineWhisperModelConfig();
                w.setEncoder(new File(dir, WhisperModelManager.encoderFile(model)).getAbsolutePath());
                w.setDecoder(new File(dir, WhisperModelManager.decoderFile(model)).getAbsolutePath());
                w.setLanguage(lg);
                w.setTask("transcribe");

                OfflineModelConfig mc = new OfflineModelConfig();
                mc.setWhisper(w);
                mc.setTokens(new File(dir, WhisperModelManager.tokensFile(model)).getAbsolutePath());
                int cores = Runtime.getRuntime().availableProcessors();
                mc.setNumThreads(Math.max(2, Math.min(4, cores >= 8 ? 4 : cores - 1)));
                mc.setDebug(false);
                mc.setProvider("cpu");

                FeatureConfig fc = new FeatureConfig();
                fc.setSampleRate(SR);
                fc.setFeatureDim(80);

                OfflineRecognizerConfig cfg = new OfflineRecognizerConfig();
                cfg.setFeatConfig(fc);
                cfg.setModelConfig(mc);
                cfg.setDecodingMethod("greedy_search");
                return new OfflineRecognizer(null, cfg);
            } catch (Throwable e) {
                Log.e(TAG, "cannot load whisper " + model, e);
                return null;
            }
        }

        // ---------------- PCM → ۱۶k mono ----------------
        private void setRate(int inRate) {
            ratio = inRate <= 0 ? 1 : (double) inRate / SR;
            binFill = 0;
            acc = 0;
        }

        private void consume(ByteBuffer ob, int ch, boolean floatPcm) {
            if (ch < 1) ch = 1;
            if (floatPcm) {
                FloatBuffer fb = ob.asFloatBuffer();
                while (fb.remaining() >= ch && !cancel) {
                    float s = 0;
                    for (int c = 0; c < ch; c++) s += fb.get();
                    push(s / ch);
                }
            } else {
                ShortBuffer sb = ob.asShortBuffer();
                while (sb.remaining() >= ch && !cancel) {
                    float s = 0;
                    for (int c = 0; c < ch; c++) s += sb.get();
                    push(s / ch / 32768f);
                }
            }
        }

        private void push(float x) {
            if (ratio <= 1.0000001 && ratio >= 0.9999999) { add(x); return; }
            double w = 1.0;
            while (w > 1e-12) {
                double space = ratio - binFill;
                double take = Math.min(space, w);
                acc += x * take;
                binFill += take;
                w -= take;
                if (binFill >= ratio - 1e-9) {
                    add((float) (acc / ratio));
                    acc = 0;
                    binFill = 0;
                }
            }
        }

        // ---------------- پنجره‌بندی روی سکوت ----------------
        private void add(float x) {
            if (len >= buf.length) { cut(len); }
            buf[len++] = x;
            sumSq += (double) x * x;
            emitted++;
            if (++sinceCheck >= FRAME) {
                sinceCheck = 0;
                check();
            }
        }

        private void check() {
            int minW = first ? FIRST_MIN : NEXT_MIN;
            int maxW = first ? FIRST_MAX : NEXT_MAX;
            if (len >= maxW) {
                int from = Math.max(minW, len - SEARCH_BACK);
                int bestStart = len - FRAME;
                double best = Double.MAX_VALUE;
                for (int s = from; s + FRAME <= len; s += FRAME) {
                    double r = rms(buf, s, s + FRAME);
                    if (r < best) { best = r; bestStart = s; }
                }
                cut(Math.min(len, bestStart + FRAME));
            } else if (len >= minW) {
                double tail = rms(buf, len - (SR * 4) / 10, len);
                double all = Math.sqrt(sumSq / Math.max(1, len));
                if (tail < Math.max(0.003, all * 0.25)) cut(len);
            }
        }

        private void cut(int n) {
            if (n <= 0) return;
            float[] win = java.util.Arrays.copyOf(buf, n);
            long off = base;
            int rest = len - n;
            if (rest > 0) System.arraycopy(buf, n, buf, 0, rest);
            len = Math.max(0, rest);
            base += n;
            sumSq = 0;
            for (int i = 0; i < len; i++) sumSq += (double) buf[i] * buf[i];
            first = false;
            decodeWindow(win, off / (double) SR);
        }

        private void decodeWindow(float[] win, double offSec) {
            if (cancel) return;
            double r = rms(win, 0, win.length);
            if (r < SILENT_RMS) return;

            // محدوده‌ی واقعاً گفتاری (برای زمانِ دقیق‌تر + کم‌کردنِ هذیانِ Whisper روی سکوت)
            int nf = win.length / FRAME;
            double thr = Math.max(0.005, r * 0.2);
            int f0 = -1, f1 = -1;
            for (int f = 0; f < nf; f++) {
                double fr = rms(win, f * FRAME, (f + 1) * FRAME);
                if (fr >= thr) { if (f0 < 0) f0 = f; f1 = f; }
            }
            if (f0 < 0) return;
            int a = Math.max(0, (f0 - 2) * FRAME);
            int b = Math.min(win.length, (f1 + 3) * FRAME);
            if (b - a < SR / 2) return;
            float[] sub = java.util.Arrays.copyOfRange(win, a, b);

            OfflineStream st = null;
            String text;
            try {
                st = rec.createStream();
                st.acceptWaveform(sub, SR);
                rec.decode(st);
                text = clean(rec.getResult(st).getText());
            } catch (Throwable e) {
                Log.e(TAG, "decode failed", e);
                return;
            } finally {
                if (st != null) { try { st.release(); } catch (Throwable ignored) {} }
            }
            if (cancel) return;
            if (text.isEmpty() || WhisperEngine.looksLikeLoop(text)) return;
            if (text.equalsIgnoreCase(lastText)) return;
            lastText = text;

            double s = offSec + f0 * 0.1;
            double e = offSec + Math.min(nf, f1 + 1) * 0.1;
            double done = (offSec + win.length / (double) SR);
            double frac = durationSec > 0 ? Math.min(1.0, done / durationSec) : 0;
            l.onChunk(id, text, s, Math.max(e, s + 0.3), frac);
        }

        private static double rms(float[] a, int from, int to) {
            if (to <= from) return 0;
            double sum = 0;
            for (int i = from; i < to; i++) sum += (double) a[i] * a[i];
            return Math.sqrt(sum / (to - from));
        }

        private static String clean(String t) {
            if (t == null) return "";
            return t.replaceAll("\\s+", " ").trim();
        }
    }
}
