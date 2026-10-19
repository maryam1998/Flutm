package com.getcapacitor;

import org.json.JSONException;
import org.json.JSONObject;

/** Shim: مثل JSObject کاپاسیتور؛ put() استثنا نمی‌ده. */
public class JSObject extends JSONObject {
    public JSObject() { super(); }

    public JSObject(String json) throws JSONException { super(json); }

    @Override public JSObject put(String name, boolean value) { try { super.put(name, value); } catch (JSONException ignored) {} return this; }
    @Override public JSObject put(String name, int value) { try { super.put(name, value); } catch (JSONException ignored) {} return this; }
    @Override public JSObject put(String name, long value) { try { super.put(name, value); } catch (JSONException ignored) {} return this; }
    @Override public JSObject put(String name, double value) { try { super.put(name, value); } catch (JSONException ignored) {} return this; }
    @Override public JSObject put(String name, Object value) { try { super.put(name, value); } catch (JSONException ignored) {} return this; }
}
