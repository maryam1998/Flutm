package com.linglearn.app.overlay;

import android.content.Context;
import android.content.Intent;
import android.hardware.display.VirtualDisplay;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.concurrent.CopyOnWriteArrayList;

/**
 * 🔑 یک «مجوزِ ضبطِ صفحه/صدا» (MediaProjection) مشترک بینِ ذره‌بین و ترجمه‌ی زنده.
 *
 * قبلاً هر کدام برای خودش پنجره‌ی «Start recording or casting?» را باز می‌کرد. حالا:
 *   - هر کدام که اول شروع شود، مجوز را از کاربر می‌گیرد و اینجا نگه می‌دارد؛
 *   - دیگری (تا وقتی یکی از دو سرویس زنده است) همان مجوز را بدونِ هیچ پرسشی استفاده می‌کند؛
 *   - اندروید ۱۴+ فقط «یک VirtualDisplay برای هر MediaProjection» اجازه می‌دهد؛ پس VirtualDisplay هم
 *     اینجا می‌ماند و ذره‌بین هر بار که باز می‌شود همان را دوباره استفاده می‌کند؛
 *   - وقتی هیچ‌کدام از دو سرویس مجوز را لازم نداشت (شمارنده‌ی retain/release صفر شد) مجوز آزاد می‌شود تا
 *     نشانگرِ «در حال ضبط» از نوار وضعیت برود؛
 *   - روی اندروید ۱۳ و پایین‌تر، توکنِ مجوز نگه داشته می‌شود و بعد از بسته‌شدنِ هر دو هم دوباره پرسیده نمی‌شود
 *     (اگر کاربر خودش از نوارِ وضعیت ضبط را قطع کند، توکن دور ریخته می‌شود و دوباره می‌پرسد).
 */
final class ProjectionHolder {
    private static final String TAG = "ProjectionHolder";

    private static MediaProjection mp;
    private static VirtualDisplay vd;
    private static int users = 0;
    private static int cachedRc;
    private static Intent cachedData;            // فقط اندروید ≤۱۳

    private static final Handler H = new Handler(Looper.getMainLooper());
    private static final CopyOnWriteArrayList<Runnable> stopListeners = new CopyOnWriteArrayList<>();

    private ProjectionHolder() {}

    /** مجوزِ زنده (یا null). */
    static synchronized MediaProjection current() { return mp; }

    /** آیا می‌شود بدونِ نشان‌دادنِ پنجره‌ی اندروید، مجوز گرفت؟ (مجوزِ زنده، یا توکنِ نگه‌داشته‌شده روی اندروید ≤۱۳) */
    static synchronized boolean canReuse() {
        return mp != null || (Build.VERSION.SDK_INT < 34 && cachedData != null);
    }

    /**
     * مجوز را می‌دهد. اگر مجوزِ زنده هست همان را برمی‌گرداند (data نادیده گرفته می‌شود)؛
     * وگرنه از data (نتیجه‌ی پنجره‌ی اندروید) یا توکنِ نگه‌داشته‌شده یکی می‌سازد. شکست = null.
     * باید بعد از startForeground(نوع mediaProjection) صدا زده شود.
     */
    static synchronized MediaProjection obtain(Context ctx, int rc, Intent data) {
        if (mp != null) return mp;
        int r = rc;
        Intent d = data;
        if (d == null && Build.VERSION.SDK_INT < 34) { r = cachedRc; d = cachedData; }
        if (d == null) return null;
        try {
            MediaProjectionManager mpm = (MediaProjectionManager) ctx.getSystemService(Context.MEDIA_PROJECTION_SERVICE);
            final MediaProjection p = mpm.getMediaProjection(r, d);
            if (p == null) return null;
            p.registerCallback(new MediaProjection.Callback() {
                @Override public void onStop() { onStopped(p); }
            }, H);
            mp = p;
            if (data != null && Build.VERSION.SDK_INT < 34) { cachedRc = rc; cachedData = data; }
            return p;
        } catch (Throwable t) {
            Log.w(TAG, "obtain failed", t);
            cachedData = null;
            return null;
        }
    }

    /** مجوز بیرونی (کاربر از نوار وضعیت قطع کرد / سیستم قطع کرد). */
    private static void onStopped(MediaProjection p) {
        synchronized (ProjectionHolder.class) {
            if (mp != p) return;                       // خودمان بستیم (stopNow) — چیزی برای اطلاع‌دادن نیست
            mp = null;
            vd = null;
            users = 0;
            cachedData = null;                         // کاربر خودش قطع کرد؛ بدونِ پرسش دوباره روشن نشود
        }
        for (Runnable r : stopListeners) { try { r.run(); } catch (Throwable ignored) {} }
    }

    static void addStopListener(Runnable r) { if (r != null && !stopListeners.contains(r)) stopListeners.add(r); }
    static void removeStopListener(Runnable r) { if (r != null) stopListeners.remove(r); }

    /** یک مصرف‌کننده (سرویس) مجوز را نگه می‌دارد. */
    static synchronized void retain() { users++; }

    /** مصرف‌کننده تمام کرد؛ آخرین نفر که برود، مجوز آزاد می‌شود. */
    static synchronized void release() {
        if (users > 0) users--;
        if (users == 0) stopNow();
    }

    private static void stopNow() {
        MediaProjection p = mp;
        VirtualDisplay v = vd;
        mp = null;                                      // پیش از stop تا onStopped این را «بیرونی» حساب نکند
        vd = null;
        if (v != null) { try { v.release(); } catch (Throwable ignored) {} }
        if (p != null) { try { p.stop(); } catch (Throwable ignored) {} }
    }

    /** VirtualDisplayِ مشترک (اندروید ۱۴+: فقط یکی برای هر مجوز). */
    static synchronized VirtualDisplay display() { return vd; }
    static synchronized void setDisplay(VirtualDisplay v) { vd = v; }
}
