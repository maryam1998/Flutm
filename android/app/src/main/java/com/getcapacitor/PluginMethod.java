package com.getcapacitor;

import java.lang.annotation.*;

/** Shim: متدهایی که از فلاتر قابل‌صدا زدن هستن. */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface PluginMethod {
    String returnType() default "promise";
}
