package com.getcapacitor.annotation;

import java.lang.annotation.*;

/** Shim: جایگزین حداقلیِ Capacitor تا BubblePlugin بدون تغییر کامپایل بشه. */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface CapacitorPlugin {
    String name() default "";
}
