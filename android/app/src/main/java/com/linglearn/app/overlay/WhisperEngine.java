package com.linglearn.app.overlay;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.k2fsa.sherpa.onnx.FeatureConfig;
import com.k2fsa.sherpa.onnx.OfflineModelConfig;
import com.k2fsa.sherpa.onnx.OfflineRecognizer;
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig;
import com.k2fsa.sherpa.onnx.OfflineStream;
import com.k2fsa.sherpa.onnx.OfflineWhisperModelConfig;

import java.io.File;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * تشخیص گفتارِ آفلاین (برای آهنگ‌ها). بسته ذاتاً جریانی نیست، پس «استریمِ شبه‌زنده» داریم:
 *  - هر ~۲ تا ۶ ثانیه روی صدای جمع‌شده یک پیش‌نمایش decode می‌شه و متن حین پخش (بدونِ نیاز به مکث) می‌آد؛
 *  - وقتی مکث/طولِ کافی رسید، همون بخش «نهایی» می‌شه (دقیق‌تر) و جایگزینِ پیش‌نمایش می‌شه؛
 *  - جزئیاتِ پنجره‌های نهایی:
 *  - صدا توی پنجره‌های کوتاهِ تطبیقی (~۳ تا ۱۰ ثانیه، بسته به سرعتِ گوشی) جمع می‌شه
 *    (برش روی مکث/ساکت‌ترین نقطه، تا وسطِ کلمه قطع نشه)؛
 *  - هر پنجره توی یک نخِ جدا decode می‌شه تا feedLoop (ضبطِ صدا) هیچ‌وقت بلاک نشه؛
 *  - نتیجه با تأخیرِ چند ثانیه به BubbleService.asrFinal می‌ره (partial نداریم).
 * پنجره‌ی حداقل خودکار با زمانِ واقعیِ decode تنظیم می‌شه: گوشیِ سریع → تأخیرِ کم؛ گوشیِ کند → پنجره‌ی
 * بزرگ‌تر تا decode عقب نیفته و صدا دور ریخته نشه.
 */
final class WhisperEngine implements PcmSink {

    private static final String TAG = "WhisperEngine";
    private static final int SR = 16000;
    private static final int FRAME = SR / 10;              // ۱۰۰ms
    private static final int PARTIAL_MIN = SR;             // اولین «پیش‌نمایشِ زنده» بعد از ۱ ثانیه صدا
    private static final long PARTIAL_MIN_GAP_MS = 600;    // کمترین فاصله‌ی دو پیش‌نمایش (متنِ زنده پیوسته‌تر بیاید)
    private static final long PARTIAL_MAX_GAP_MS = 4000;

    /** زبان‌هایی که برنامه پشتیبانی می‌کند؛ تشخیصِ بیرون از این فهرست (مثلاً az) هذیانِ نویز حساب می‌شود. */
    private static final Set<String> ALLOWED = new HashSet<>(Arrays.asList(
            "en", "de", "fr", "es", "it", "pt", "nl", "tr", "fa", "ar", "ur", "ru", "ja", "ko", "zh", "hi"));
    private static final int MIN_WIN_FLOOR = 5 * SR;       // کمترین طولِ پنجره‌ی «نهایی» (پیش‌نمایش‌ها زودتر متن رو نشون می‌دن)
    private static final int MIN_WIN_CEIL = 9 * SR;        // بیشترین مقدارِ «حداقلِ تطبیقی»
    private static final int MAX_WIN = 12 * SR;
    private static final int SEARCH_BACK = 3 * SR;         // برش توی ۳ ثانیه‌ی آخرِ پنجره
    private static final int MAX_QUEUE = 3;                // عقب افتادیم → قدیمی‌ترین پنجره دور ریخته می‌شه
    private static final double SILENT_RMS = 0.004;        // پنجره‌ی تقریباً ساکت decode نمی‌شه

    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    private final Object lock = new Object();
    private final ArrayDeque<float[]> queue = new ArrayDeque<>();
    private final float[] buf = new float[MAX_WIN + SR];
    private int len = 0;
    private boolean released = false;
    private boolean failed = false;
    private int minWin = MIN_WIN_FLOOR;
    // ── استریم زنده: روی صدای در حال جمع‌شدن هر چند ثانیه یک‌بار decode می‌شه و به‌عنوان partial می‌ره
    private float[] partialReq = null;                     // آخرین درخواستِ پیش‌نمایش (فقط آخری مهمه)
    private boolean partialBusy = false;
    private int sincePartial = 0;                          // نمونه‌های رسیده از آخرین درخواستِ پیش‌نمایش
    private int epoch = 0;                                 // با هر برشِ نهایی بالا می‌ره؛ پیش‌نمایشِ کهنه دور ریخته می‌شه
    private boolean partialShown = false;                  // برای این بخش پیش‌نمایشی نشون داده شده؟
    private String lastPartialText = "";                    // زیرِ lock؛ با زمانِ decode تطبیق پیدا می‌کنه
    private double avgDecodeMs = 0;
    private String lastText = "";

    private final OfflineRecognizer recognizer;   // فقط از نخِ worker استفاده می‌شه (در حالتِ خودکار: تشخیصِ زبان)
    private final Thread worker;

    // ── تشخیصِ خودکارِ زبان (همه‌ی فیلدها فقط از نخِ worker لمس می‌شوند) ──
    private final Context ctx;
    private final String model;
    private final boolean auto;
    private final Map<String, OfflineRecognizer> pinned = new LinkedHashMap<>();   // زبان → recognizerِ قفل‌شده روی همان زبان
    private String lockedLang = null;
    private String candLang = null;
    private int candStreak = 0;

    private WhisperEngine(Context ctx, String model, boolean auto, OfflineRecognizer r) {
        this.ctx = ctx;
        this.model = model;
        this.auto = auto;
        this.recognizer = r;
        this.worker = new Thread(this::runWorker, "whisper-decode");
        this.worker.setDaemon(true);
        this.worker.start();
    }

    static boolean isAvailable(Context ctx, String model) {
        return WhisperModelManager.getModelDir(ctx, model) != null;
    }

    /** lang: کدِ دو حرفی (en, fa, ...) یا "auto"/null برای تشخیصِ خودکار. */
    static WhisperEngine create(Context ctx, String model, String lang) {
        File dir = WhisperModelManager.getModelDir(ctx, model);
        if (dir == null) return null;
        OfflineRecognizer rec = null;
        try {
            String l = SherpaModelManager.normalize(lang);
            if (l == null || "auto".equals(l)) l = "";
            rec = build(ctx, model, l);
            Log.i(TAG, "whisper " + model + " loaded, lang='" + l + "'");
            return new WhisperEngine(ctx.getApplicationContext(), model, l.isEmpty(), rec);
        } catch (Throwable e) {
            Log.e(TAG, "cannot load whisper " + model, e);
            if (rec != null) { try { rec.release(); } catch (Throwable ignored) {} }
            return null;
        }
    }

    /** یک recognizerِ Whisper روی زبانِ داده‌شده می‌سازد ("" = تشخیصِ خودکارِ خودِ Whisper). */
    private static OfflineRecognizer build(Context ctx, String model, String l) {
        File dir = WhisperModelManager.getModelDir(ctx, model);
        if (dir == null) throw new IllegalStateException("whisper model missing: " + model);
        OfflineWhisperModelConfig w = new OfflineWhisperModelConfig();
        w.setEncoder(new File(dir, WhisperModelManager.encoderFile(model)).getAbsolutePath());
        w.setDecoder(new File(dir, WhisperModelManager.decoderFile(model)).getAbsolutePath());
        w.setLanguage(l);
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
    }

    // ------------------------------------------------------------------ ورودی صدا

    @Override
    public void accept(byte[] pcm, int bytes) {
        if (pcm == null || bytes < 2) return;
        synchronized (lock) {
            if (released || failed) return;
            int n = bytes / 2;
            if (len + n > buf.length) n = buf.length - len;     // دفاعی؛ عملاً پیش نمی‌آد
            for (int i = 0; i < n; i++) {
                short s = (short) ((pcm[2 * i] & 0xff) | (pcm[2 * i + 1] << 8));
                buf[len + i] = s / 32768f;
            }
            len += n;

            sincePartial += n;
            if (len >= MAX_WIN) {
                cutAtQuietestPoint();
            } else if (len >= minWin && tailIsQuiet()) {
                enqueue(len);
            } else {
                maybeRequestPartial();
            }
        }
    }

    /** ۳۰۰ms آخر خیلی ساکت‌تر از میانگینِ پنجره‌ست؟ (مکثِ بینِ دو خط) */
    private boolean tailIsQuiet() {
        double tail = rms(len - (SR * 3) / 10, len);
        double all = rms(0, len);
        return tail < Math.max(0.003, all * 0.25);
    }

    private void cutAtQuietestPoint() {
        int from = Math.max(minWin, len - SEARCH_BACK);
        int best = len, bestFrameStart = len - FRAME;
        double bestRms = Double.MAX_VALUE;
        for (int s = from; s + FRAME <= len; s += FRAME) {
            double r = rms(s, s + FRAME);
            if (r < bestRms) { bestRms = r; bestFrameStart = s; }
        }
        best = Math.min(len, bestFrameStart + FRAME);
        enqueue(best);
    }

    /** n نمونه‌ی اول رو توی صفِ decode می‌ذاره و باقی‌مونده رو به ابتدای بافر می‌بره. (زیرِ lock) */
    private void enqueue(int n) {
        float[] win = java.util.Arrays.copyOf(buf, n);
        int rest = len - n;
        if (rest > 0) System.arraycopy(buf, n, buf, 0, rest);
        len = Math.max(0, rest);
        epoch++;                       // پیش‌نمایشِ در راهِ این بخش دیگه معتبر نیست؛ نسخه‌ی نهایی می‌آد
        partialReq = null;
        sincePartial = 0;

        if (rms(win, 0, win.length) < SILENT_RMS) return;       // ساکت → decode نکن
        while (queue.size() >= MAX_QUEUE) {
            queue.pollFirst();
            Log.w(TAG, "decoder is behind real-time; dropped oldest window");
        }
        queue.addLast(win);
        lock.notifyAll();
    }

    /** هر ~۲ تا ۶ ثانیه (بسته به سرعتِ گوشی) از صدای جمع‌شده تا الان یک پیش‌نمایشِ متن می‌گیریم. (زیرِ lock) */
    private void maybeRequestPartial() {
        if (partialBusy || partialReq != null || len < PARTIAL_MIN || !queue.isEmpty()) return;
        long gapMs = (long) Math.max(PARTIAL_MIN_GAP_MS, Math.min(PARTIAL_MAX_GAP_MS, avgDecodeMs * 1.3));
        if (sincePartial < gapMs * SR / 1000) return;
        if (rms(0, len) < SILENT_RMS) { sincePartial = 0; return; }       // ساکت → decode نکن
        partialReq = java.util.Arrays.copyOf(buf, len);
        sincePartial = 0;
        lock.notifyAll();
    }

    private double rms(int from, int to) { return rms(buf, from, to); }

    private static double rms(float[] a, int from, int to) {
        if (to <= from) return 0;
        double sum = 0;
        for (int i = from; i < to; i++) sum += (double) a[i] * a[i];
        return Math.sqrt(sum / (to - from));
    }

    // ------------------------------------------------------------------ decode (نخِ worker)

    private void runWorker() {
        try {
            while (true) {
                float[] win = null, part = null;
                int partEpoch = 0;
                synchronized (lock) {
                    while (!released && queue.isEmpty() && partialReq == null) {
                        try { lock.wait(); } catch (InterruptedException e) { return; }
                    }
                    if (released) return;
                    if (!queue.isEmpty()) {
                        win = queue.pollFirst();                    // نسخه‌ی نهایی همیشه اولویت داره
                    } else {
                        part = partialReq; partialReq = null;
                        partialBusy = true;
                        partEpoch = epoch;
                    }
                }
                if (win != null) {
                    long t0 = android.os.SystemClock.elapsedRealtime();
                    String text = decode(win, true);
                    adaptWindow(android.os.SystemClock.elapsedRealtime() - t0);
                    if (text == null) {
                        synchronized (lock) { failed = true; }
                        MAIN.post(BubbleService::asrFallback);
                        return;
                    }
                    boolean hadPartial;
                    synchronized (lock) {
                        if (released) return;
                        hadPartial = partialShown;
                        partialShown = false;
                        lastPartialText = "";
                    }
                    if (!text.isEmpty()) {
                        final String t = text;
                        MAIN.post(() -> BubbleService.asrFinal(t));
                    } else if (hadPartial) {
                        MAIN.post(BubbleService::asrCommit);        // نسخه‌ی نهایی چیزِ جدیدی نداشت؛ همون پیش‌نمایش بمونه
                    }
                } else if (part != null) {
                    long t0 = android.os.SystemClock.elapsedRealtime();
                    String text = decode(part, false);
                    adaptWindow(android.os.SystemClock.elapsedRealtime() - t0);
                    synchronized (lock) {
                        partialBusy = false;
                        if (released) return;
                        if (text == null) continue;                 // خطای پیش‌نمایش مهم نیست؛ نسخه‌ی نهایی تلاش می‌کنه
                        if (partEpoch != epoch) continue;           // وسطِ decode برشِ نهایی خورد → کهنه‌ست
                        if (text.isEmpty() || text.equals(lastPartialText)) continue;
                        lastPartialText = text;
                        partialShown = true;
                    }
                    final String t = text;
                    MAIN.post(() -> BubbleService.asrPartial(t));
                }
            }
        } finally {
            releasePinned();
            try { recognizer.release(); } catch (Throwable e) { Log.w(TAG, "release", e); }
        }
    }

    /** حداقلِ طولِ پنجره رو کمی بیشتر از زمانِ واقعیِ decode نگه می‌داره تا صف عقب نیفته. */
    private void adaptWindow(long ms) {
        synchronized (lock) {
            avgDecodeMs = (avgDecodeMs == 0) ? ms : (avgDecodeMs * 0.6 + ms * 0.4);
            long want = (long) (avgDecodeMs * 1.25 * SR / 1000.0);
            minWin = (int) Math.max(MIN_WIN_FLOOR, Math.min(MIN_WIN_CEIL, want));
        }
    }

    /** نتیجه‌ی یک decode: متنِ خام + زبانِ تشخیص‌داده‌شده (ممکن است null باشد). */
    private static final class Res {
        final String text, lang;
        Res(String text, String lang) { this.text = text; this.lang = lang; }
    }

    private Res run(OfflineRecognizer rec, float[] samples) throws Exception {
        OfflineStream st = null;
        try {
            st = rec.createStream();
            st.acceptWaveform(samples, SR);
            rec.decode(st);
            Object r = rec.getResult(st);
            String text = clean(((com.k2fsa.sherpa.onnx.OfflineRecognizerResult) r).getText());
            String lang = null;
            try {   // نسخه‌های مختلفِ AAR: اگر getLang نبود، فقط از روی متن تصمیم می‌گیریم
                Object l = r.getClass().getMethod("getLang").invoke(r);
                lang = normLang(l == null ? null : String.valueOf(l));
            } catch (Throwable ignored) { /* بدونِ زبانِ مدل */ }
            return new Res(text, lang);
        } finally {
            if (st != null) { try { st.release(); } catch (Throwable ignored) {} }
        }
    }

    /** "<|es|>" ، "es-ES" ، "Spanish" … → "es" (نامعلوم = null) */
    private static String normLang(String l) {
        if (l == null) return null;
        String t = l.replace("<|", "").replace("|>", "").trim().toLowerCase(Locale.ROOT);
        if (t.isEmpty()) return null;
        int dash = t.indexOf('-');
        if (dash > 0) t = t.substring(0, dash);
        return t.length() == 2 ? t : null;
    }

    /** recognizerِ قفل‌شده روی [lang] (در صورت نبودن ساخته می‌شود؛ حداکثر ۲ تا نگه داشته می‌شود، برای «small» فقط ۱ تا). */
    private OfflineRecognizer pinnedFor(String lang) {
        OfflineRecognizer r = pinned.get(lang);
        if (r != null) { pinned.remove(lang); pinned.put(lang, r); return r; }
        try {
            long t0 = android.os.SystemClock.elapsedRealtime();
            r = build(ctx, model, lang);
            Log.i(TAG, "pinned whisper '" + lang + "' ready in ms=" + (android.os.SystemClock.elapsedRealtime() - t0));
        } catch (Throwable e) {
            Log.w(TAG, "cannot pin whisper to " + lang, e);
            return null;
        }
        int cap = "small".equals(model) ? 1 : 2;
        while (pinned.size() >= cap) {
            String oldest = pinned.keySet().iterator().next();
            OfflineRecognizer o = pinned.remove(oldest);
            if (o != null) { try { o.release(); } catch (Throwable ignored) {} }
        }
        pinned.put(lang, r);
        return r;
    }

    private void releasePinned() {
        for (OfflineRecognizer r : pinned.values()) { try { r.release(); } catch (Throwable ignored) {} }
        pinned.clear();
    }

    /** متنِ پاک‌شده؛ "" = چیزی نبود/هذیان؛ null = خطا. */
    private String decode(float[] samples, boolean isFinal) {
        try {
            Res res;
            if (!auto) {
                res = run(recognizer, samples);                       // زبانِ مشخص: مثلِ قبل
            } else if (lockedLang != null && !isFinal) {
                OfflineRecognizer pr = pinnedFor(lockedLang);         // پیش‌نمایشِ زنده: روی زبانِ قفل‌شده (سریع و بی‌هذیان)
                res = run(pr != null ? pr : recognizer, samples);
            } else {
                res = run(recognizer, samples);                       // پنجره‌ی نهایی / هنوز قفل نشده: تشخیصِ زبان
                res = resolveAuto(res, samples, isFinal);
            }
            String text = res == null ? "" : res.text;
            if (text.isEmpty() || looksLikeLoop(text)) return "";
            if (!isFinal) return text;                       // پیش‌نمایش: dedupe نداره
            if (text.equalsIgnoreCase(lastText)) return "";
            lastText = text;
            return text;
        } catch (Throwable e) {
            Log.e(TAG, "decode failed", e);
            return null;
        }
    }

    /**
     * 🌐 تصمیمِ زبان در حالتِ خودکار.
     *  ۱) زبانِ خارج از فهرستِ پشتیبانی‌شده (مثلاً az) یا متنِ تکراری = هذیان → دور ریخته می‌شود
     *     (یا اگر زبانی قفل شده، همان پنجره با زبانِ قفل‌شده دوباره decode می‌شود).
     *  ۲) قفلِ اول: دو تشخیصِ هم‌نظر (یا یک پنجره‌ی نهایی با ≥۶ کلمه).
     *  ۳) تغییرِ زبان: فقط روی پنجره‌ی نهایی، با ≥۴ کلمه و تأییدِ تشخیصِ متنی؛ هر پنجره زبانِ خودش را دارد.
     */
    private Res resolveAuto(Res res, float[] samples, boolean isFinal) throws Exception {
        if (res.text.isEmpty()) return res;
        final int words = res.text.split("\\s+").length;
        final String byText = LangDetect.detect(res.text);
        String lang = res.lang != null ? res.lang : byText;

        boolean bad = looksLikeLoop(res.text) || words < 1
                || (lang != null && !ALLOWED.contains(lang))
                || (res.lang != null && byText != null && ALLOWED.contains(byText) && !byText.equals(res.lang) && words >= 4);
        if (bad) {
            if (lockedLang != null) {                       // همان صدا با زبانِ قفل‌شده
                OfflineRecognizer pr = pinnedFor(lockedLang);
                if (pr != null) {
                    Res again = run(pr, samples);
                    if (!again.text.isEmpty() && !looksLikeLoop(again.text)) return again;
                }
            }
            return new Res("", null);
        }
        if (lang == null) return res;                       // زبان معلوم نیست ولی متن سالم است: همان را نشان بده

        if (lockedLang == null) {
            if (lang.equals(candLang)) candStreak++; else { candLang = lang; candStreak = 1; }
            if (candStreak >= 2 || (isFinal && words >= 6)) { lockedLang = lang; candLang = null; candStreak = 0; }
            return res;
        }
        if (lang.equals(lockedLang)) { candLang = null; candStreak = 0; return res; }
        if (!isFinal || words < 4) {                         // تغییرِ زبان فقط با شواهدِ کافی
            OfflineRecognizer pr = pinnedFor(lockedLang);
            if (pr != null) {
                Res again = run(pr, samples);
                if (!again.text.isEmpty() && !looksLikeLoop(again.text)) return again;
            }
            return new Res("", null);
        }
        lockedLang = lang;                                   // گوینده/ویدیو زبان را عوض کرد
        candLang = null; candStreak = 0;
        return res;
    }

    private static String clean(String t) {
        if (t == null) return "";
        return t.replaceAll("\\s+", " ").trim();
    }

    /** موتور روی موسیقی گاهی یه عبارت رو بی‌نهایت تکرار می‌کنه؛ اون خروجی رو دور بریز. */
    static boolean looksLikeLoop(String t) {
        String s = t.toLowerCase(Locale.ROOT);
        // هذیانِ کلمه‌ای: «az az az az …» یا فقط یکی‌دو کلمه‌ی تکراری در متنی بلند
        String[] ws = s.trim().split("\\s+");
        if (ws.length >= 5) {
            Set<String> dw = new HashSet<>(Arrays.asList(ws));
            if (dw.size() <= Math.max(1, ws.length / 4)) return true;
            int run = 1;
            for (int i = 1; i < ws.length; i++) {
                run = ws[i].equals(ws[i - 1]) ? run + 1 : 1;
                if (run >= 4) return true;
            }
        }
        if (s.length() < 24) return false;
        Set<String> distinct = new HashSet<>();
        int total = 0;
        for (int i = 0; i + 3 <= s.length(); i++) {
            distinct.add(s.substring(i, i + 3));
            total++;
        }
        return total >= 20 && distinct.size() < total * 0.2;
    }

    @Override
    public void release() {
        synchronized (lock) {
            if (released) return;
            released = true;
            queue.clear();
            len = 0;
            lock.notifyAll();
        }
        // recognizer رو خودِ worker (بعد از تمام شدنِ decode ی جاری) آزاد می‌کنه.
    }
}
