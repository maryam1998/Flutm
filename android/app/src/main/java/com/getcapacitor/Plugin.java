package com.getcapacitor;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;

/** Shim: کلاس پایه‌ی Plugin کاپاسیتور؛ فقط چیزهایی که BubblePlugin لازم داره. */
public class Plugin {

    /** پل فلاتر این رو پیاده می‌کنه تا رویدادها به دارت برسن. */
    public interface Emitter {
        void emit(String event, JSObject data, boolean retainUntilConsumed);
    }

    private Context context;
    private Activity activity;
    private Emitter emitter;

    // ---------- API مورد استفاده‌ی BubblePlugin ----------
    public Context getContext() { return context; }
    public Activity getActivity() { return activity; }

    public void load() {}

    protected void handleOnNewIntent(Intent intent) {}

    public void notifyListeners(String event, JSObject data) { notifyListeners(event, data, false); }

    public void notifyListeners(String event, JSObject data, boolean retainUntilConsumed) {
        Emitter e = emitter;
        if (e != null) e.emit(event, data == null ? new JSObject() : data, retainUntilConsumed);
    }

    // ---------- API داخلیِ پل ----------
    public final void attach(Context appContext, Emitter emitter) {
        this.context = appContext;
        this.emitter = emitter;
    }

    public final void setActivity(Activity a) { this.activity = a; }

    public final void dispatchNewIntent(Intent intent) { handleOnNewIntent(intent); }
}
