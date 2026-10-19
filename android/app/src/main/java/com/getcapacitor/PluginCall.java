package com.getcapacitor;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

/** Shim: PluginCall کاپاسیتور، روی MethodChannel فلاتر. */
public class PluginCall {
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    private final MethodChannel.Result result;
    private final JSONObject data;
    private volatile boolean done = false;

    @SuppressWarnings("unchecked")
    public PluginCall(Object args, MethodChannel.Result result) {
        this.result = result;
        JSONObject d = null;
        if (args instanceof Map) {
            try { d = new JSONObject((Map<String, Object>) args); } catch (Throwable ignored) {}
        }
        this.data = d != null ? d : new JSONObject();
    }

    // ---------- ورودی‌ها ----------
    private boolean has(String name) { return data.has(name) && !data.isNull(name); }

    public String getString(String name) { return has(name) ? data.optString(name, null) : null; }
    public String getString(String name, String def) { return has(name) ? data.optString(name, def) : def; }

    public Boolean getBoolean(String name) { return has(name) ? Boolean.valueOf(data.optBoolean(name)) : null; }
    public Boolean getBoolean(String name, Boolean def) { return has(name) ? Boolean.valueOf(data.optBoolean(name)) : def; }

    public Double getDouble(String name) { return has(name) ? Double.valueOf(data.optDouble(name)) : null; }
    public Double getDouble(String name, Double def) { return has(name) ? Double.valueOf(data.optDouble(name)) : def; }

    public Integer getInt(String name) { return has(name) ? Integer.valueOf(data.optInt(name)) : null; }
    public Integer getInt(String name, Integer def) { return has(name) ? Integer.valueOf(data.optInt(name)) : def; }

    public JSArray getArray(String name) {
        JSONArray a = data.optJSONArray(name);
        if (a == null) return null;
        try { return new JSArray(a.toString()); } catch (Throwable e) { return null; }
    }

    public JSObject getData() {
        try { return new JSObject(data.toString()); } catch (Throwable e) { return new JSObject(); }
    }

    // ---------- خروجی‌ها ----------
    public void resolve() { resolve(null); }

    public void resolve(JSObject ret) {
        if (done) return;
        done = true;
        final Object plain = ret == null ? new HashMap<String, Object>() : toPlain(ret);
        MAIN.post(new Runnable() { @Override public void run() { try { result.success(plain); } catch (Throwable ignored) {} } });
    }

    public void reject(String msg) { reject(msg, "REJECTED"); }
    public void reject(String msg, Exception e) { reject(msg, "REJECTED"); }

    public void reject(final String msg, final String code) {
        if (done) return;
        done = true;
        MAIN.post(new Runnable() { @Override public void run() { try { result.error(code == null ? "REJECTED" : code, msg, null); } catch (Throwable ignored) {} } });
    }

    public void unimplemented(String msg) {
        if (done) return;
        done = true;
        MAIN.post(new Runnable() { @Override public void run() { try { result.notImplemented(); } catch (Throwable ignored) {} } });
    }

    // ---------- تبدیل JSON → ساختارِ ساده‌ی قابل‌ارسال به دارت ----------
    public static Object toPlain(Object o) {
        if (o == null || o == JSONObject.NULL) return null;
        if (o instanceof JSONObject) {
            JSONObject j = (JSONObject) o;
            Map<String, Object> m = new HashMap<>();
            Iterator<String> it = j.keys();
            while (it.hasNext()) {
                String k = it.next();
                m.put(k, toPlain(j.opt(k)));
            }
            return m;
        }
        if (o instanceof JSONArray) {
            JSONArray a = (JSONArray) o;
            List<Object> l = new ArrayList<>(a.length());
            for (int i = 0; i < a.length(); i++) l.add(toPlain(a.opt(i)));
            return l;
        }
        return o;
    }
}
