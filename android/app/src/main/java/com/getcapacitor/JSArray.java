package com.getcapacitor;

import org.json.JSONArray;
import org.json.JSONException;

/** Shim: مثل JSArray کاپاسیتور. */
public class JSArray extends JSONArray {
    public JSArray() { super(); }

    public JSArray(String json) throws JSONException { super(json); }
}
