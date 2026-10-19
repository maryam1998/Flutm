package com.linglearn.app.overlay;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;

/**
 * ورود یک‌باره به یوتیوب داخلِ خودِ اپ. کوکی‌ها در CookieManagerِ مشترکِ برنامه می‌مانند و
 * مسیرِ WebViewِ دریافتِ زیرنویس (YtCaptionFetcher) با همان نشست باز می‌شود، پس bot-check نمی‌خورد.
 * بهتر است یک حسابِ جدا (نه حسابِ اصلی) استفاده شود.
 */
public class YtLoginActivity extends Activity {

    static final String HOME = "https://m.youtube.com/";

    /** آیا کوکی‌ی نشستِ گوگل/یوتیوب داریم؟ */
    static boolean isLoggedIn() {
        try {
            CookieManager cm = CookieManager.getInstance();
            String a = cm.getCookie("https://www.youtube.com");
            String b = cm.getCookie("https://accounts.google.com");
            String all = (a == null ? "" : a) + ";" + (b == null ? "" : b);
            return all.contains("SAPISID") || all.contains("__Secure-3PSID") || all.contains("SID=");
        } catch (Throwable t) {
            return false;
        }
    }

    static String cleanUa(WebSettings st) {
        return st.getUserAgentString().replace("; wv", "").replace("Version/4.0 ", "");
    }

    private WebView wv;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);

        Button done = new Button(this);
        done.setText("تمام شد ✔ (بستن)");
        done.setOnClickListener(v -> finish());
        root.addView(done, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        FrameLayout holder = new FrameLayout(this);
        root.addView(holder, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        wv = new WebView(this);
        holder.addView(wv, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT, Gravity.TOP));
        setContentView(root);

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        cm.setAcceptThirdPartyCookies(wv, true);
        WebSettings st = wv.getSettings();
        st.setJavaScriptEnabled(true);
        st.setDomStorageEnabled(true);
        st.setUserAgentString(cleanUa(st));
        wv.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView v, String url) {
                try { CookieManager.getInstance().flush(); } catch (Throwable ignored) {}
            }
        });
        wv.loadUrl("https://accounts.google.com/ServiceLogin?service=youtube&continue="
                + "https%3A%2F%2Fm.youtube.com%2F");
    }

    @Override
    protected void onPause() {
        super.onPause();
        try { CookieManager.getInstance().flush(); } catch (Throwable ignored) {}
    }

    @Override
    protected void onDestroy() {
        try { CookieManager.getInstance().flush(); } catch (Throwable ignored) {}
        if (wv != null) { try { wv.destroy(); } catch (Throwable ignored) {} }
        super.onDestroy();
    }
}
