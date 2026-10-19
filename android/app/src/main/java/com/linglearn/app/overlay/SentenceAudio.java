package com.linglearn.app.overlay;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

/**
 * 🎙 ترجمه‌ی زنده: صدای ضبط‌شده‌ی سیستم (PCM 16kHz mono) را در یک بافرِ حلقوی نگه می‌دارد،
 * موقعِ بسته شدنِ هر جمله تکه‌ی همان جمله را جدا می‌کند (silence کنار زده + بلندیِ صدا یکدست)،
 * و دکمه‌ی ↺ همان تکه را با صدای خودِ گوینده پخش می‌کند.
 *
 * صدای پخش‌شده از خودِ برنامه است و در BubbleService با excludeUid از ضبط کنار گذاشته شده؛
 * پس دوباره وارد تشخیصِ گفتار نمی‌شود.
 */
final class SentenceAudio {

    static final int RATE = 16000;
    private static final int CAP_SAMPLES = RATE * 150;        // ۲٫۵ دقیقه صدای اخیر
    private static final int MAX_SENTENCE = RATE * 45;        // یک جمله بیشتر از ۴۵ ثانیه نگه داشته نمی‌شود
    private static final int MIN_SENTENCE = (int) (RATE * 0.45);
    private static final int FRAME = RATE / 50;               // ۲۰ms
    private static final double VOICED_RMS = 170.0;
    private static final int PAD_HEAD = (int) (RATE * 0.15);
    private static final int PAD_TAIL = (int) (RATE * 0.25);
    private static final int REPEAT_GAP_MS = 500;

    private static final Object LOCK = new Object();
    private static final short[] RING = new short[CAP_SAMPLES];
    private static long total = 0;                             // تعداد کلِ sample های نوشته‌شده (همیشه صعودی)

    private static final Object PLAY = new Object();
    private static int token = 0;
    private static AudioTrack track;

    private SentenceAudio() {}

    // ───────── ضبط ─────────

    /** PCM 16kHz mono 16-bit little-endian. از thread ی feedLoop صدا زده می‌شود. */
    static void write(byte[] pcm, int len) {
        if (pcm == null || len < 2) return;
        int n = len / 2;
        synchronized (LOCK) {
            int pos = (int) (total % CAP_SAMPLES);
            for (int i = 0; i < n; i++) {
                RING[pos] = (short) ((pcm[2 * i] & 0xff) | (pcm[2 * i + 1] << 8));
                if (++pos == CAP_SAMPLES) pos = 0;
            }
            total += n;
        }
    }

    /** شمارنده‌ی فعلی (sample). */
    static long now() {
        synchronized (LOCK) { return total; }
    }

    /** شروعِ ضبطِ تازه: صدای قبلی دیگر معتبر نیست (شمارنده ادامه پیدا می‌کند). */
    static void reset() {
        synchronized (LOCK) { java.util.Arrays.fill(RING, (short) 0); }
    }

    /** تکه‌ی [from, to) را برمی‌دارد، silence ابتدا/انتها را حذف و بلندی را یکدست می‌کند. null = چیزی برای پخش نبود. */
    static short[] extract(long from, long to) {
        short[] a;
        synchronized (LOCK) {
            long lo = Math.max(0, total - CAP_SAMPLES);
            from = Math.max(from, lo);
            to = Math.min(to, total);
            if (to - from > MAX_SENTENCE) from = to - MAX_SENTENCE;
            if (to - from < MIN_SENTENCE) return null;
            int n = (int) (to - from);
            a = new short[n];
            int pos = (int) (from % CAP_SAMPLES);
            for (int i = 0; i < n; i++) {
                a[i] = RING[pos];
                if (++pos == CAP_SAMPLES) pos = 0;
            }
        }
        int frames = a.length / FRAME;
        int first = -1, last = -1;
        for (int f = 0; f < frames; f++) {
            double sum = 0;
            int o = f * FRAME;
            for (int i = 0; i < FRAME; i++) sum += (double) a[o + i] * a[o + i];
            if (Math.sqrt(sum / FRAME) > VOICED_RMS) {
                if (first < 0) first = f;
                last = f;
            }
        }
        if (first < 0) return null;                            // فقط سکوت
        int s = Math.max(0, first * FRAME - PAD_HEAD);
        int e = Math.min(a.length, (last + 1) * FRAME + PAD_TAIL);
        if (e - s < MIN_SENTENCE) return null;
        short[] out = new short[e - s];
        int peak = 1;
        for (int i = 0; i < out.length; i++) {
            short v = a[s + i];
            out[i] = v;
            int m = v < 0 ? -v : v;
            if (m > peak) peak = m;
        }
        double gain = Math.min(4.0, 26000.0 / peak);           // صدای ضبط‌شده معمولاً کم‌صداست
        if (gain > 1.1) {
            for (int i = 0; i < out.length; i++) {
                int v = (int) Math.round(out[i] * gain);
                out[i] = (short) Math.max(-32768, Math.min(32767, v));
            }
        }
        return out;
    }

    // ───────── پخش ─────────

    /** times < 0 = بی‌نهایت. onDone فقط وقتی صدا می‌شود که پخش خودش تمام شده باشد (نه با stop()). */
    static void play(final short[] pcm, final int times, final Runnable onDone) {
        if (pcm == null || pcm.length == 0) return;
        final int my;
        synchronized (PLAY) {
            stopLocked();
            my = ++token;
        }
        Thread th = new Thread(() -> run(pcm, times, onDone, my), "sentence-replay");
        th.setDaemon(true);
        th.start();
    }

    static void stop() {
        synchronized (PLAY) { stopLocked(); }
    }

    private static void stopLocked() {
        token++;
        AudioTrack t = track;
        if (t != null) {
            try { t.pause(); } catch (Throwable ignored) {}
        }
    }

    private static boolean alive(int my) {
        synchronized (PLAY) { return token == my; }
    }

    private static void sleepWhileAlive(int my, long ms) {
        long end = System.currentTimeMillis() + ms;
        while (alive(my)) {
            long left = end - System.currentTimeMillis();
            if (left <= 0) return;
            try { Thread.sleep(Math.min(left, 20)); } catch (InterruptedException e) { return; }
        }
    }

    private static void run(short[] pcm, int times, Runnable onDone, int my) {
        AudioTrack t = null;
        boolean finished = false;
        try {
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build();
            AudioFormat fmt = new AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build();
            t = new AudioTrack(attrs, fmt, pcm.length * 2, AudioTrack.MODE_STATIC,
                    AudioManager.AUDIO_SESSION_ID_GENERATE);
            if (t.write(pcm, 0, pcm.length) != pcm.length) return;
            synchronized (PLAY) {
                if (token != my) return;
                track = t;
            }
            int rep = 0;
            while (alive(my) && (times < 0 || rep < times)) {
                if (rep > 0) {
                    t.stop();
                    t.reloadStaticData();
                }
                t.play();
                while (alive(my) && t.getPlaybackHeadPosition() < pcm.length) {
                    try { Thread.sleep(20); } catch (InterruptedException e) { return; }
                }
                rep++;
                if (alive(my) && (times < 0 || rep < times)) sleepWhileAlive(my, REPEAT_GAP_MS);
            }
            finished = alive(my);
        } catch (Throwable ignored) {
            // پخش نشد؛ بی‌صدا تمام می‌شود
            finished = alive(my);
        } finally {
            synchronized (PLAY) {
                if (track == t) track = null;
            }
            if (t != null) {
                try { t.stop(); } catch (Throwable ignored) {}
                try { t.release(); } catch (Throwable ignored) {}
            }
            if (finished && onDone != null) onDone.run();
        }
    }
}
