package com.linglearn.app.overlay;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * پلِ فلاتر ⟷ BubblePlugin.
 * هر MethodCall با اسمِ یکی از متدهای @PluginMethod مستقیم به همون متد می‌ره (با reflection)،
 * و هر notifyListeners به EventChannel می‌ره. منطقِ جاوا دست‌نخورده می‌مونه.
 */
public class LinglearnBridge implements FlutterPlugin, ActivityAware,
        MethodChannel.MethodCallHandler, EventChannel.StreamHandler, PluginRegistry.NewIntentListener {

    public static final String METHOD_CHANNEL = "com.linglearn.app/bubble";
    public static final String EVENT_CHANNEL = "com.linglearn.app/bubble_events";

    private final Handler main = new Handler(Looper.getMainLooper());
    private HandlerThread workerThread;
    private Handler worker;

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private volatile EventChannel.EventSink sink;
    private final List<Map<String, Object>> retained = new ArrayList<>();

    private BubblePlugin plugin;
    private boolean loaded = false;
    private ActivityPluginBinding activityBinding;

    // ───────────── FlutterPlugin ─────────────
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        Context app = binding.getApplicationContext();

        workerThread = new HandlerThread("LinglearnBridge");
        workerThread.start();
        worker = new Handler(workerThread.getLooper());

        plugin = new BubblePlugin();
        plugin.attach(app, new Plugin.Emitter() {
            @Override public void emit(String event, JSObject data, boolean retain) { dispatchEvent(event, data, retain); }
        });

        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (methodChannel != null) methodChannel.setMethodCallHandler(null);
        if (eventChannel != null) eventChannel.setStreamHandler(null);
        sink = null;
        if (workerThread != null) workerThread.quitSafely();
    }

    // ───────────── ActivityAware ─────────────
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        plugin.setActivity(binding.getActivity());
        binding.addOnNewIntentListener(this);
        if (!loaded) {
            loaded = true;
            try { plugin.load(); } catch (Throwable ignored) {}
        }
    }

    @Override public void onDetachedFromActivityForConfigChanges() { detachActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { onAttachedToActivity(binding); }
    @Override public void onDetachedFromActivity() { detachActivity(); }

    private void detachActivity() {
        if (activityBinding != null) activityBinding.removeOnNewIntentListener(this);
        activityBinding = null;
        if (plugin != null) plugin.setActivity(null);
    }

    @Override
    public boolean onNewIntent(@NonNull Intent intent) {
        try { plugin.dispatchNewIntent(intent); } catch (Throwable ignored) {}
        return false;
    }

    // ───────────── MethodChannel ─────────────
    @Override
    public void onMethodCall(@NonNull final MethodCall call, @NonNull final MethodChannel.Result result) {
        final PluginCall pc = new PluginCall(call.arguments, result);
        worker.post(new Runnable() {
            @Override public void run() {
                try {
                    Method m = BubblePlugin.class.getMethod(call.method, PluginCall.class);
                    if (m.getAnnotation(PluginMethod.class) == null) { pc.unimplemented(call.method); return; }
                    m.invoke(plugin, pc);
                } catch (NoSuchMethodException e) {
                    pc.unimplemented(call.method);
                } catch (InvocationTargetException e) {
                    Throwable c = e.getCause() != null ? e.getCause() : e;
                    pc.reject(String.valueOf(c.getMessage()));
                } catch (Throwable e) {
                    pc.reject(String.valueOf(e.getMessage()));
                }
            }
        });
    }

    // ───────────── EventChannel ─────────────
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        sink = events;
        // رویدادهای نگه‌داشته‌شده (مثل authCallback) حالا تحویل داده می‌شن
        final List<Map<String, Object>> pending;
        synchronized (retained) { pending = new ArrayList<>(retained); retained.clear(); }
        for (final Map<String, Object> ev : pending) {
            main.post(new Runnable() { @Override public void run() { EventChannel.EventSink s = sink; if (s != null) s.success(ev); } });
        }
    }

    @Override
    public void onCancel(Object arguments) { sink = null; }

    @SuppressWarnings("unchecked")
    private void dispatchEvent(String event, JSObject data, boolean retain) {
        final Map<String, Object> ev = new HashMap<>();
        ev.put("event", event);
        ev.put("data", PluginCall.toPlain(data));
        if (sink == null) {
            if (retain) synchronized (retained) { retained.add(ev); }
            return;
        }
        main.post(new Runnable() {
            @Override public void run() {
                EventChannel.EventSink s = sink;
                if (s != null) s.success(ev);
            }
        });
    }
}
