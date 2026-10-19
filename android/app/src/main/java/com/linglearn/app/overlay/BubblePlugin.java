package com.linglearn.app.overlay;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.provider.Settings;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@CapacitorPlugin(name = "BubblePlugin")
public class BubblePlugin extends Plugin {

    // ✅ موتور Piper توی پردازه‌ی جدا (TtsService) اجرا می‌شه؛ این کلاس فقط پیام می‌فرسته.
    // اگه کدِ native کرش کنه فقط اون پردازه می‌میره و اپ بسته نمی‌شه.
    // با هر speak/stop بالا می‌ره؛ speakSystem ی که قبل از stop شروع شده، دیگه پخش نشه
    private static final AtomicInteger SPEAK_SEQ = new AtomicInteger(0);
    private static final String TTS_PREFS = "tts_engine";

    private static String lastTtsLang(Context ctx) {
        try { return ctx.getSharedPreferences(TTS_PREFS, Context.MODE_PRIVATE).getString("last_lang", null); }
        catch (Throwable e) { return null; }
    }

    private static void rememberTtsLang(Context ctx, String lang) {
        try {
            SharedPreferences sp = ctx.getSharedPreferences(TTS_PREFS, Context.MODE_PRIVATE);
            if (!lang.equals(sp.getString("last_lang", null))) sp.edit().putString("last_lang", lang).apply();
        } catch (Throwable ignored) {}
    }

    private void emitSpeakDone(String lang, String text, String id, boolean ok) {
        JSObject ret = new JSObject();
        ret.put("lang", lang);
        ret.put("text", text);
        if (id != null) ret.put("id", id);
        ret.put("ok", ok);
        notifyListeners("ttsSpeakDone", ret);
    }

    // ================================================================
    // ============ ورود با گوگل (deep link) ==========================
    // ================================================================

    private static final String AUTH_SCHEME = "com.linglearn.app";
    private static final String AUTH_HOST = "login-callback";

    /** اگه intent مالِ آدرسِ بازگشتِ ورود بود، به JS (رویداد authCallback) می‌فرسته. */
    private void dispatchAuthIntent(Intent intent) {
        // در نسخه‌ی فلاتر، supabase_flutter خودش لینک بازگشتِ ورود را می‌گیرد؛
        // اینجا نه رویداد می‌فرستیم و نه intent را پاک می‌کنیم (وگرنه ورود با گوگل خراب می‌شد).
    }

    private static volatile BubblePlugin inst;

    /** از پنلِ شناور: «یه لغت تو صفِ اپ گذاشته شد» — اگه اپ زنده است همان لحظه وارد می‌شود. */
    static void notifyWordQueued() {
        BubblePlugin p = inst;
        if (p == null) return;
        try { p.notifyListeners("wordQueued", new JSObject()); } catch (Throwable ignored) {}
    }

    @Override
    public void load() {
        super.load();
        inst = this;
        try {
            TtsClient.init(getContext(), (lang, text, id, ok) ->
                    emitSpeakDone(lang, text, id.isEmpty() ? null : id, ok));
        } catch (Throwable ignored) {}
        try {
            if (getActivity() != null) dispatchAuthIntent(getActivity().getIntent());
        } catch (Throwable ignored) {}
    }

    @Override
    protected void handleOnNewIntent(Intent intent) {
        super.handleOnNewIntent(intent);
        dispatchAuthIntent(intent);
    }

    // openExternal({ url }) — باز کردنِ آدرس. اگر لینک مالِ یک برنامه‌ی شناخته‌شده باشد
    // (یوتیوب، اینستاگرام، تیک‌تاک، …) و آن برنامه نصب باشد، مستقیم همان برنامه (و همان
    // ویدیو) باز می‌شود؛ وگرنه مرورگرِ سیستم.
    @PluginMethod
    public void openExternal(PluginCall call) {
        String url = call.getString("url");
        if (url == null || !(url.startsWith("https://") || url.startsWith("http://"))) {
            call.reject("invalid url");
            return;
        }
        try {
            Uri uri = Uri.parse(url);
            for (String pkg : packagesForHost(uri.getHost())) {
                try {
                    Intent a = new Intent(Intent.ACTION_VIEW, uri);
                    a.setPackage(pkg);
                    a.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    getContext().startActivity(a);
                    call.resolve();
                    return;
                } catch (android.content.ActivityNotFoundException ignored) {
                    // این برنامه نصب نیست / لینک را نمی‌گیرد → بعدی یا مرورگر
                }
            }
            Intent i = new Intent(Intent.ACTION_VIEW, uri);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) {
            call.reject("cannot open browser: " + e.getMessage());
        }
    }

    private static String[] packagesForHost(String host) {
        if (host == null) return new String[0];
        String h = host.toLowerCase(java.util.Locale.ROOT).replaceFirst("^(www|m|vm|vt|mobile)\\.", "");
        if (h.endsWith("youtube.com") || h.equals("youtu.be"))
            return new String[] {"com.google.android.youtube"};
        if (h.endsWith("instagram.com"))
            return new String[] {"com.instagram.android"};
        if (h.endsWith("tiktok.com"))
            return new String[] {"com.zhiliaoapp.musically", "com.ss.android.ugc.trill"};
        if (h.equals("t.me") || h.endsWith("telegram.me"))
            return new String[] {"org.telegram.messenger", "org.thunderdog.challegram"};
        if (h.endsWith("facebook.com") || h.equals("fb.watch") || h.equals("fb.me"))
            return new String[] {"com.facebook.katana"};
        if (h.equals("x.com") || h.endsWith("twitter.com"))
            return new String[] {"com.twitter.android"};
        if (h.endsWith("snapchat.com"))
            return new String[] {"com.snapchat.android"};
        if (h.endsWith("reddit.com") || h.equals("redd.it"))
            return new String[] {"com.reddit.frontpage"};
        if (h.endsWith("vimeo.com"))
            return new String[] {"com.vimeo.android.videoapp"};
        if (h.endsWith("twitch.tv"))
            return new String[] {"tv.twitch.android.app"};
        if (h.endsWith("linkedin.com"))
            return new String[] {"com.linkedin.android"};
        if (h.endsWith("pinterest.com") || h.equals("pin.it"))
            return new String[] {"com.pinterest"};
        if (h.endsWith("spotify.com"))
            return new String[] {"com.spotify.music"};
        return new String[0];
    }

    // openApp({ pkg }) — باز کردنِ برنامه‌ی منبعِ صدا (مثلاً پلیری که فایل در آن پخش می‌شد)
    @PluginMethod
    public void openApp(PluginCall call) {
        String pkg = call.getString("pkg");
        if (pkg == null || pkg.isEmpty()) { call.reject("invalid package"); return; }
        try {
            Intent i = getContext().getPackageManager().getLaunchIntentForPackage(pkg);
            if (i == null) { call.reject("app not found"); return; }
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) {
            call.reject("cannot open app: " + e.getMessage());
        }
    }

    @PluginMethod
    public void checkPermission(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("granted", Settings.canDrawOverlays(getContext()));
        call.resolve(ret);
    }

    @PluginMethod
    public void requestPermission(PluginCall call) {
        Context ctx = getContext();
        JSObject ret = new JSObject();
        if (Settings.canDrawOverlays(ctx)) {
            ret.put("granted", true);
            call.resolve(ret);
            return;
        }
        Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + ctx.getPackageName()));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        ctx.startActivity(i);
        ret.put("granted", false);
        call.resolve(ret);
    }

    // showBubble({ targetLang?, sourceLang?, translationTone? })
    @PluginMethod
    public void showBubble(PluginCall call) {
        Context ctx = getContext();
        if (!Settings.canDrawOverlays(ctx)) {
            call.reject("Overlay permission not granted");
            return;
        }
        BubbleService.saveLangs(ctx, call.getString("targetLang"), call.getString("sourceLang"));
        BubbleService.saveTargets(ctx, targetsCsv(call));
        BubbleService.saveTone(ctx, call.getString("translationTone"));
        Intent i = new Intent(ctx, BubbleService.class).setAction(BubbleService.ACTION_SHOW);
        ctx.startForegroundService(i);
        call.resolve();
    }

    @PluginMethod
    public void hideBubble(PluginCall call) {
        Context ctx = getContext();
        ctx.stopService(new Intent(ctx, BubbleService.class));
        call.resolve();
    }

    // setLanguages({ targetLang?, targetLangs?: string[], sourceLang?, translationTone? })
    //   targetLang  = UI language (messages), targetLangs = every translation language the user picked
    @PluginMethod
    public void setLanguages(PluginCall call) {
        BubbleService.saveLangs(getContext(), call.getString("targetLang"), call.getString("sourceLang"));
        BubbleService.saveTargets(getContext(), targetsCsv(call));
        BubbleService.saveTone(getContext(), call.getString("translationTone"));
        BubbleService.settingsChanged();
        call.resolve();
    }

    /** "fa,fr,ar" from the optional targetLangs array (null when the caller did not send one). */
    private static String targetsCsv(PluginCall call) {
        JSArray arr = call.getArray("targetLangs");
        if (arr == null) return null;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < arr.length(); i++) {
            String s = arr.optString(i, "").trim();
            if (s.isEmpty()) continue;
            if (sb.length() > 0) sb.append(',');
            sb.append(s);
        }
        return sb.toString();
    }

    // setPanelFont({ font: "default"|"modern"|"classic"|"elegant"|"rounded"|"warm" }) — فونتِ کادرِ ترجمه از «نوع فونت» تنظیماتِ اپ می‌آید
    @PluginMethod
    public void setPanelFont(PluginCall call) {
        BubbleService.pushAppFont(getContext(), call.getString("font"));
        BubbleService.settingsChanged();
        call.resolve();
    }

    // setUiLang({ lang: "fa"|"en" }) — زبانِ رابطِ اپ؛ کادرِ ترجمه‌ی زنده و ذره‌بین هم به همین زبان نشون داده می‌شن
    @PluginMethod
    public void setUiLang(PluginCall call) {
        BubbleService.saveUiLang(getContext(), call.getString("lang"));
        BubbleService.settingsChanged();
        call.resolve();
    }

    // setDisplayMode({ mode: "both"|"original"|"translation" })
    @PluginMethod
    public void setDisplayMode(PluginCall call) {
        BubbleService.saveDisplayMode(getContext(), call.getString("mode"));
        BubbleService.settingsChanged();
        call.resolve();
    }

    // 🎨 setPanelColor({ color: "#RRGGBB" }) — رنگِ کادرِ حبابِ ترجمه‌ی زنده و ذره‌بین
    @PluginMethod
    public void setPanelColor(PluginCall call) {
        String c = call.getString("color");
        try {
            int rgb = android.graphics.Color.parseColor(c == null ? "#1C2541" : c.trim()) & 0xFFFFFF;
            BubbleService.savePanelColor(getContext(), rgb);
            BubbleService.settingsChanged();
            call.resolve();
        } catch (Exception e) {
            call.reject("bad color");
        }
    }

    // 🔍 حبابِ ذره‌بین: magnifierStart({ targetLang?, targetLangs?, sourceLang? }) — اول مجوزِ ضبطِ صفحه از کاربر می‌پرسد
    @PluginMethod
    public void magnifierStart(PluginCall call) {
        Context ctx = getContext();
        if (!Settings.canDrawOverlays(ctx)) {
            call.reject("Overlay permission not granted");
            return;
        }
        BubbleService.saveLangs(ctx, call.getString("targetLang"), call.getString("sourceLang"));
        BubbleService.saveTargets(ctx, targetsCsv(call));
        // 🔑 مجوزِ ضبطِ صفحه با ترجمه‌ی زنده مشترک است: اگر قبلاً داده شده، بدونِ پنجره‌ی اندروید شروع کن
        if (ProjectionHolder.canReuse()) {
            try {
                ctx.startForegroundService(new Intent(ctx, MagnifierService.class)
                        .setAction(MagnifierService.ACTION_START)
                        .putExtra(MagnifierService.EXTRA_REUSE, true));
                call.resolve();
                return;
            } catch (Exception ignored) { /* می‌افتد روی پنجره‌ی معمولی */ }
        }
        Intent i = new Intent(ctx, ProjectionActivity.class)
                .putExtra(ProjectionActivity.EXTRA_MAGNIFIER, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        ctx.startActivity(i);
        call.resolve();
    }

    @PluginMethod
    public void magnifierStop(PluginCall call) {
        Context ctx = getContext();
        ctx.stopService(new Intent(ctx, MagnifierService.class));
        call.resolve();
    }

    @PluginMethod
    public void magnifierIsRunning(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("running", MagnifierService.running);
        call.resolve(ret);
    }

    @PluginMethod
    public void isRunning(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("running", BubbleService.running);
        call.resolve(ret);
    }

    // ================================================================
    // ============ 📺 زیرنویس زنده‌ی یوتیوب (MediaSession) ===========
    // ================================================================

    // ytCheckAccess() → { granted }  — آیا «دسترسی به اعلان‌ها» برای این اپ روشنه؟
    @PluginMethod
    public void ytCheckAccess(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("granted", YtMedia.hasAccess(getContext()));
        call.resolve(ret);
    }

    // ytRequestAccess() — صفحه‌ی تنظیماتِ «دسترسی به اعلان‌ها» رو باز می‌کنه
    @PluginMethod
    public void ytRequestAccess(PluginCall call) {
        YtMedia.openAccessSettings(getContext());
        JSObject ret = new JSObject();
        ret.put("granted", YtMedia.hasAccess(getContext()));
        call.resolve(ret);
    }

    // ytLoginOpen() — صفحه‌ی ورود به یوتیوب (یک‌بار) را باز می‌کند
    @PluginMethod
    public void ytLoginOpen(PluginCall call) {
        try {
            android.content.Intent i = new android.content.Intent(getContext(), YtLoginActivity.class);
            i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve(new JSObject());
        } catch (Throwable t) {
            call.reject(String.valueOf(t));
        }
    }

    // ytLoginStatus() → { loggedIn }
    @PluginMethod
    public void ytLoginStatus(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("loggedIn", YtLoginActivity.isLoggedIn());
        call.resolve(ret);
    }

    // ytSetEnabled({ enabled, offsetMs? }) — حالت یوتیوبِ حباب رو روشن/خاموش می‌کنه.
    // اگه حباب هنوز بالا نیومده (showBubble تازه صدا زده شده)، درخواست نگه داشته می‌شه.
    @PluginMethod
    public void ytSetEnabled(PluginCall call) {
        Boolean enabled = call.getBoolean("enabled", true);
        Double off = call.getDouble("offsetMs", 0.0);
        BubbleService.setYoutubeEnabled(getContext(), enabled == null || enabled,
                off == null ? 0L : off.longValue());
        call.resolve();
    }

    // ytIsActive() → { active }
    @PluginMethod
    public void ytIsActive(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("active", BubbleService.youtubeActive());
        call.resolve(ret);
    }

    // ytSavedList() → { items: [...] } — زیرنویس‌های ذخیره‌شده از حباب که هنوز وارد اپ نشده‌اند
    @PluginMethod
    public void ytSavedList(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("items", YtSaved.list(getContext()));
        call.resolve(ret);
    }

    // ytSavedAck({ items: [{ key, rev }] }) — بعد از واردشدن به اپ، از صف پاک می‌شوند
    @PluginMethod
    public void ytSavedAck(PluginCall call) {
        try {
            YtSaved.ack(getContext(), call.getArray("items"));
        } catch (Exception ignored) {}
        call.resolve();
    }

    // wordQueueList() → { items: [...] } — لغت/عبارت‌هایی که از پنلِ شناور زده شده و هنوز وارد اپ نشده
    @PluginMethod
    public void wordQueueList(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("items", WordQueue.list(getContext()));
        call.resolve(ret);
    }

    // wordQueueAck({ items: [{ key, rev }] }) — بعد از واردشدن به اپ، از صف پاک می‌شوند
    @PluginMethod
    public void wordQueueAck(PluginCall call) {
        try {
            WordQueue.ack(getContext(), call.getArray("items"));
        } catch (Exception ignored) {}
        call.resolve();
    }

    // ytSeek({ ms }) — جلو/عقب بردنِ ویدیوی یوتیوب (از همان MediaController)
    @PluginMethod
    public void ytSeek(PluginCall call) {
        Double ms = call.getDouble("ms");
        if (ms == null) { call.reject("ms is required"); return; }
        JSObject ret = new JSObject();
        ret.put("ok", YtMedia.seek(ms.longValue()));
        call.resolve(ret);
    }

    // ================================================================
    // ============ STT: بسته‌های تشخیص گفتار (Zipformer) ==============
    // ================================================================

    // checkModelStatus({ lang: "en" })
    @PluginMethod
    public void checkModelStatus(PluginCall call) {
        Context ctx = getContext();
        String lang = call.getString("lang", "en");
        JSObject ret = new JSObject();
        ret.put("supported", SherpaModelManager.isAvailable(lang));
        ret.put("downloaded", SherpaModelManager.getModelDir(ctx, lang) != null);
        ret.put("downloading", SherpaModelManager.isDownloading());
        ret.put("partialBytes", SherpaModelManager.getSttPartialBytes(ctx, lang));
        String act = SherpaModelManager.activeDownloadLang();
        ret.put("activeLang", act == null ? "" : act);
        call.resolve(ret);
    }

    // cancelModelDownload() — توقفِ دانلودِ بسته‌ی تشخیص گفتار (فایل .part می‌مونه تا ادامه پیدا کنه)
    @PluginMethod
    public void cancelModelDownload(PluginCall call) {
        SherpaModelManager.cancelDownload();
        call.resolve();
    }

    // downloadModel({ lang: "en" })
    @PluginMethod
    public void downloadModel(PluginCall call) {
        final Context ctx = getContext();
        final String lang = call.getString("lang", "en");

        if (!SherpaModelManager.isAvailable(lang)) {
            call.reject("STT not supported for language: " + lang);
            return;
        }
        if (SherpaModelManager.getModelDir(ctx, lang) != null) {
            JSObject ret = new JSObject();
            ret.put("alreadyDownloaded", true);
            call.resolve(ret);
            return;
        }

        SherpaModelManager.downloadModel(ctx.getApplicationContext(), lang,
                new SherpaModelManager.ProgressCallback() {
                    @Override
                    public void onProgress(String l, long done, long total) {
                        JSObject ret = new JSObject();
                        ret.put("lang", l);
                        ret.put("bytes", done);
                        ret.put("total", total);
                        notifyListeners("modelDownloadProgress", ret);
                    }

                    @Override
                    public void onDone(String l) {
                        JSObject ret = new JSObject();
                        ret.put("lang", l);
                        notifyListeners("modelDownloadDone", ret);
                    }

                    @Override
                    public void onError(String l, Exception e) {
                        JSObject ret = new JSObject();
                        ret.put("lang", l);
                        ret.put("cancelled", e instanceof SherpaModelManager.DownloadCancelled);
                        ret.put("error", e.getMessage() != null ? e.getMessage() : "unknown");
                        notifyListeners("modelDownloadError", ret);
                    }
                });

        call.resolve();
    }

    // deleteModel({ lang: "en" })
    @PluginMethod
    public void deleteModel(PluginCall call) {
        Context ctx = getContext();
        String lang = call.getString("lang", "en");
        SherpaModelManager.deleteModel(ctx, lang);
        call.resolve();
    }

    // ================================================================
    // ============ STT برای آهنگ‌ها: Whisper (آفلاین، MIT) ===========
    // ================================================================

    // setSttEngine({ engine: "sherpa" | "whisper", model: "tiny"|"base"|"small" })
    @PluginMethod
    public void setSttEngine(PluginCall call) {
        String engine = call.getString("engine", "sherpa");
        String model = call.getString("model", "base");
        if (!"whisper".equals(engine)) engine = "sherpa";
        if (!WhisperModelManager.isValid(model)) model = "base";
        try {
            getContext().getSharedPreferences("bubble_prefs", Context.MODE_PRIVATE).edit()
                    .putString("sttEngine", engine).putString("whisperModel", model).apply();
        } catch (Throwable ignored) {}
        call.resolve();
    }

    // getWhisperStatus() → { engine, model, models: [{id, downloaded, approxMb, partialBytes}], downloading, activeModel }
    @PluginMethod
    public void getWhisperStatus(PluginCall call) {
        Context ctx = getContext();
        SharedPreferences sp = ctx.getSharedPreferences("bubble_prefs", Context.MODE_PRIVATE);
        JSArray arr = new JSArray();
        for (String id : WhisperModelManager.models()) {
            JSObject o = new JSObject();
            o.put("id", id);
            o.put("downloaded", WhisperModelManager.getModelDir(ctx, id) != null);
            o.put("approxMb", WhisperModelManager.approxMb(id));
            o.put("partialBytes", WhisperModelManager.partialBytes(ctx, id));
            arr.put(o);
        }
        JSObject ret = new JSObject();
        ret.put("engine", sp.getString("sttEngine", "sherpa"));
        ret.put("model", sp.getString("whisperModel", "base"));
        ret.put("models", arr);
        ret.put("downloading", WhisperModelManager.isDownloading());
        String active = WhisperModelManager.activeModel();
        ret.put("activeModel", active == null ? "" : active);
        call.resolve(ret);
    }

    // downloadWhisperModel({ model: "base" })  → events: whisperDownloadProgress / Done / Error
    @PluginMethod
    public void downloadWhisperModel(PluginCall call) {
        final Context ctx = getContext();
        final String model = call.getString("model", "base");
        if (!WhisperModelManager.isValid(model)) {
            call.reject("unknown whisper model: " + model);
            return;
        }
        if (WhisperModelManager.getModelDir(ctx, model) != null) {
            JSObject ret = new JSObject();
            ret.put("alreadyDownloaded", true);
            call.resolve(ret);
            return;
        }
        WhisperModelManager.download(ctx.getApplicationContext(), model, new WhisperModelManager.Callback() {
            @Override public void onProgress(String m, long done, long total) {
                JSObject o = new JSObject();
                o.put("model", m); o.put("bytes", done); o.put("total", total);
                notifyListeners("whisperDownloadProgress", o);
            }
            @Override public void onDone(String m) {
                JSObject o = new JSObject();
                o.put("model", m);
                notifyListeners("whisperDownloadDone", o);
            }
            @Override public void onError(String m, Exception e) {
                JSObject o = new JSObject();
                o.put("model", m);
                o.put("cancelled", e instanceof WhisperModelManager.Cancelled);
                o.put("error", e.getMessage() != null ? e.getMessage() : "unknown");
                notifyListeners("whisperDownloadError", o);
            }
        });
        call.resolve();
    }

    // cancelWhisperDownload()  — فایل .part می‌مونه تا دانلودِ بعدی ادامه پیدا کنه
    @PluginMethod
    public void cancelWhisperDownload(PluginCall call) {
        WhisperModelManager.cancel();
        call.resolve();
    }

    // deleteWhisperModel({ model: "base" })
    @PluginMethod
    public void deleteWhisperModel(PluginCall call) {
        WhisperModelManager.delete(getContext(), call.getString("model", ""));
        call.resolve();
    }

    // ================================================================
    // ============ همگام‌سازیِ متن با صوتِ آپلودیِ داستان ============
    // ================================================================

    // syncTranscribe({ job, path, lang, model: "tiny"|"base"|"small" })
    //   فایلِ صوتی رو پنجره‌پنجره با Whisper رونویسی می‌کنه و هر پنجره رو بلافاصله می‌فرسته:
    //   events: syncChunk {job, text, start, end, frac} / syncDone {job} / syncError {job, code, error}
    @PluginMethod
    public void syncTranscribe(PluginCall call) {
        final Context ctx = getContext();
        final String job = call.getString("job", "");
        final String path = call.getString("path", "");
        final String lang = call.getString("lang", "");
        String model = call.getString("model", "base");
        if (!WhisperModelManager.isValid(model)) model = "base";
        if (WhisperModelManager.getModelDir(ctx, model) == null) {
            call.reject("NO_MODEL");
            return;
        }
        if (path == null || path.isEmpty() || !new java.io.File(path).isFile()) {
            call.reject("NO_AUDIO");
            return;
        }
        AudioSyncTranscriber.start(ctx.getApplicationContext(), job, path, lang, model,
                new AudioSyncTranscriber.Listener() {
                    @Override public void onChunk(String j, String text, double start, double end, double frac) {
                        JSObject o = new JSObject();
                        o.put("job", j); o.put("text", text);
                        o.put("start", start); o.put("end", end); o.put("frac", frac);
                        notifyListeners("syncChunk", o);
                    }
                    @Override public void onDone(String j) {
                        JSObject o = new JSObject();
                        o.put("job", j);
                        notifyListeners("syncDone", o);
                    }
                    @Override public void onError(String j, String code, String message) {
                        JSObject o = new JSObject();
                        o.put("job", j); o.put("code", code);
                        o.put("error", message == null ? "" : message);
                        notifyListeners("syncError", o);
                    }
                });
        call.resolve();
    }

    // syncTranscribeCancel()
    @PluginMethod
    public void syncTranscribeCancel(PluginCall call) {
        AudioSyncTranscriber.cancel();
        call.resolve();
    }

    // ================================================================
    // ============ TTS: تبدیل متن به گفتار (Piper/VITS) ==============
    // ================================================================

    // setTtsEnabled({ enabled: true })
    @PluginMethod
    public void setTtsEnabled(PluginCall call) {
        Boolean enabled = call.getBoolean("enabled", false);
        try {
            getContext().getSharedPreferences("bubble_prefs", Context.MODE_PRIVATE)
                    .edit().putBoolean("ttsEnabled", enabled != null && enabled).apply();
        } catch (Throwable ignored) {}
        call.resolve();
    }

    // checkTtsStatus({ lang: "fa" })
    @PluginMethod
    public void checkTtsStatus(PluginCall call) {
        Context ctx = getContext();
        String lang = call.getString("lang", "en");
        JSObject ret = new JSObject();
        ret.put("supported", SherpaModelManager.isTtsAvailable(lang));
        ret.put("downloaded", SherpaModelManager.getTtsModelDir(ctx, lang) != null);
        ret.put("downloading", SherpaModelManager.isTtsDownloading(lang));
        call.resolve(ret);
    }

    // getTtsCatalog() → { languages: [{lang, downloaded}], downloading, downloadingLang }
    // یک‌جا وضعیتِ همه‌ی زبان‌هایی که بسته‌ی آفلاین دارن (برای صفحه‌ی تنظیمات)
    @PluginMethod
    public void getTtsCatalog(PluginCall call) {
        Context ctx = getContext();
        JSArray arr = new JSArray();
        for (String l : SherpaModelManager.ttsLanguages()) {
            JSObject o = new JSObject();
            o.put("lang", l);
            o.put("downloaded", SherpaModelManager.getTtsModelDir(ctx, l) != null);
            o.put("partialBytes", SherpaModelManager.getTtsPartialBytes(ctx, l));
            arr.put(o);
        }
        JSObject ret = new JSObject();
        ret.put("languages", arr);
        ret.put("downloading", SherpaModelManager.isTtsDownloading());
        JSArray dls = new JSArray();
        for (String x : SherpaModelManager.getTtsDownloadingLangs()) dls.put(x);
        ret.put("downloadingLangs", dls);
        call.resolve(ret);
    }

    // downloadTtsModel({ lang: "fa" })
    @PluginMethod
    public void downloadTtsModel(PluginCall call) {
        final Context ctx = getContext();
        final String lang = call.getString("lang", "en");

        if (!SherpaModelManager.isTtsAvailable(lang)) {
            call.reject("TTS not supported for language: " + lang);
            return;
        }
        if (SherpaModelManager.getTtsModelDir(ctx, lang) != null) {
            JSObject ret = new JSObject();
            ret.put("alreadyDownloaded", true);
            call.resolve(ret);
            return;
        }

        // سرویس پیش‌زمینه: دانلود حتی بعد از بیرون‌رفتن از اپ ادامه پیدا می‌کنه
        ModelDownloadService.start(ctx);

        SherpaModelManager.downloadTtsModel(ctx.getApplicationContext(), lang,
                new SherpaModelManager.ProgressCallback() {
                    @Override
                    public void onProgress(String l, long done, long total) {
                        JSObject ret = new JSObject();
                        ret.put("lang", l);
                        ret.put("bytes", done);
                        ret.put("total", total);
                        notifyListeners("ttsModelDownloadProgress", ret);
                    }

                    @Override
                    public void onDone(String l) {
                        TtsClient.resetCrash(l);
                        TtsClient.preload(l);   // ⚡ مدلِ تازه دانلودشده فوراً لود و گرم بشه
                        JSObject ret = new JSObject();
                        ret.put("lang", l);
                        notifyListeners("ttsModelDownloadDone", ret);
                    }

                    @Override
                    public void onError(String l, Exception e) {
                        JSObject ret = new JSObject();
                        ret.put("lang", l);
                        if (e instanceof SherpaModelManager.DownloadCancelled) {
                            notifyListeners("ttsModelDownloadCancelled", ret);
                            return;
                        }
                        ret.put("error", e.getMessage() != null ? e.getMessage() : "unknown");
                        notifyListeners("ttsModelDownloadError", ret);
                    }
                });

        call.resolve();
    }

    // cancelTtsDownload({ lang }) — توقفِ دانلودِ یه زبان (بخشِ دانلودشده می‌مونه و بعداً ادامه پیدا می‌کنه)
    @PluginMethod
    public void cancelTtsDownload(PluginCall call) {
        SherpaModelManager.cancelTtsDownload(call.getString("lang", ""));
        call.resolve();
    }

    // cancelAllTtsDownloads() — توقفِ همه‌ی دانلودها
    @PluginMethod
    public void cancelAllTtsDownloads(PluginCall call) {
        SherpaModelManager.cancelAllTtsDownloads();
        call.resolve();
    }

    // deleteTtsModel({ lang: "fa" })
    @PluginMethod
    public void deleteTtsModel(PluginCall call) {
        Context ctx = getContext();
        String lang = call.getString("lang", "en");
        // اگه همین زبان الان توی حافظه لوده، اول آزادش کن (وگرنه فایلِ بسته درگیره)
        String n = SherpaModelManager.normalize(lang);
        if (n != null) {
            TtsClient.releaseLang(n);
            TtsClient.resetCrash(n);
        }
        SherpaModelManager.deleteTtsModel(ctx, lang);
        call.resolve();
    }

    /**
     * ✅ متد اصلی خواندن متن با TTS
     * speak({ text: "سلام", lang: "fa", speed: 1.0, id: "..." })
     * بعد از تمام‌شدنِ واقعیِ پخش، event «ttsSpeakDone» با { lang, text, id, ok } فرستاده می‌شه
     * (ok=false یعنی شکستِ واقعی → سمتِ JS باید fallback کنه).
     */
    @PluginMethod
    public void speak(final PluginCall call) {
        final Context ctx = getContext().getApplicationContext();
        final String text = call.getString("text");
        final String lang = SherpaModelManager.normalize(call.getString("lang", "en"));
        final String id = call.getString("id");
        Double sp = call.getDouble("speed", 1.0);

        if (text == null || text.trim().isEmpty()) {
            call.reject("text is empty");
            return;
        }
        if (lang == null) {
            call.reject("language is empty");
            return;
        }
        if (SherpaModelManager.getTtsModelDir(ctx, lang) == null) {
            call.reject("TTS model not downloaded for language: " + lang);
            return;
        }

        final float speed = (sp == null || sp <= 0) ? 1.0f : sp.floatValue();
        rememberTtsLang(ctx, lang);

        // Piper برای این زبان بعد از کرشِ پشتِ‌هم غیرفعال شده → همین الان شکست (JS می‌ره سراغ fallback)
        if (TtsClient.isBlocked(lang)) {
            call.resolve();
            TtsClient.failFast(lang, text, id == null ? "" : id);
            return;
        }
        call.resolve();
        TtsClient.speak(lang, text, speed, id);
    }

    /**
     * ✅ گرم‌کردنِ موتور: preloadTts({ lang? }) — بدونِ lang، آخرین زبانِ استفاده‌شده
     * (یا اولین زبانِ دانلودشده). فوراً resolve می‌شه و لود توی پس‌زمینه انجام می‌شه.
     */
    @PluginMethod
    public void preloadTts(final PluginCall call) {
        final Context ctx = getContext().getApplicationContext();
        String l = SherpaModelManager.normalize(call.getString("lang"));
        call.resolve();
        // بدونِ lang: آخرین زبانِ استفاده‌شده + یک زبانِ دانلودشده‌ی دیگر (متن‌های دوزبانه، مثلاً فارسی+انگلیسی،
        // هر دو مدل را لازم دارند؛ هر دو از قبل لود می‌شوند تا سوئیچ بینشان بدون تأخیر باشد)
        java.util.LinkedHashSet<String> want = new java.util.LinkedHashSet<>();
        if (l != null) want.add(l);
        else {
            String last = SherpaModelManager.normalize(lastTtsLang(ctx));
            if (last != null) want.add(last);
            for (String x : SherpaModelManager.ttsLanguages()) {
                if (want.size() >= 2) break;
                if (SherpaModelManager.getTtsModelDir(ctx, x) != null) want.add(x);
            }
        }
        int n = 0;
        for (String x : want) {
            if (n >= 2) break;
            if (SherpaModelManager.getTtsModelDir(ctx, x) == null) continue;
            if (TtsClient.isBlocked(x)) continue;
            TtsClient.preload(x);
            n++;
        }
    }

    /**
     * ✅ صدای جمله‌ی بعدی رو پیش‌پیش بساز (تا موقعِ نوبتش بدونِ تأخیر پخش بشه).
     * prefetchTts({ text, lang, speed }) — اگه موتورِ این زبان لود نیست، نادیده گرفته می‌شه.
     */
    @PluginMethod
    public void prefetchTts(PluginCall call) {
        String text = call.getString("text");
        String lang = SherpaModelManager.normalize(call.getString("lang", "en"));
        Double sp = call.getDouble("speed", 1.0);
        call.resolve();
        if (text == null || text.trim().isEmpty() || lang == null) return;
        if (TtsClient.isBlocked(lang)) return;
        TtsClient.prefetch(lang, text, (sp == null || sp <= 0) ? 1.0f : sp.floatValue());
    }

    // ---------------- TTS خودِ گوشی (android.speech.tts) ----------------
    private static volatile SystemTts systemTts;

    static SystemTts sys(Context ctx) {
        SystemTts s = systemTts;
        if (s == null) {
            synchronized (BubblePlugin.class) {
                if (systemTts == null) systemTts = new SystemTts(ctx.getApplicationContext());
                s = systemTts;
            }
        }
        return s;
    }

    // checkSystemTts({ lang }) → { available }
    @PluginMethod
    public void checkSystemTts(final PluginCall call) {
        final Context ctx = getContext().getApplicationContext();
        final String lang = call.getString("lang", "en");
        new Thread(() -> {
            JSObject ret = new JSObject();
            ret.put("available", sys(ctx).isLanguageAvailable(lang));
            call.resolve(ret);
        }, "sys-tts-check").start();
    }

    // speakSystem({ text, lang, speed, id }) — بعد از پایان، رویداد «ttsSpeakDone» با { id, ok }
    @PluginMethod
    public void speakSystem(final PluginCall call) {
        final Context ctx = getContext().getApplicationContext();
        final String text = call.getString("text");
        final String lang = call.getString("lang", "en");
        final String id = call.getString("id");
        Double sp = call.getDouble("speed", 1.0);
        final float speed = (sp == null || sp <= 0) ? 1.0f : sp.floatValue();
        if (text == null || text.trim().isEmpty()) {
            call.reject("text is empty");
            return;
        }
        call.resolve();
        final int mySeq = SPEAK_SEQ.incrementAndGet();
        new Thread(() -> {
            if (mySeq != SPEAK_SEQ.get()) { emitSpeakDone(lang, text, id, true); return; }
            sys(ctx).speak(text, lang, speed, id, ok -> emitSpeakDone(lang, text, id, ok));
        }, "sys-tts-speak").start();
    }

    /** ✅ توقف TTS */
    @PluginMethod
    public void stopSpeaking(PluginCall call) {
        SPEAK_SEQ.incrementAndGet();
        SystemTts st = systemTts;
        if (st != null) st.stop();
        TtsClient.stop();
        call.resolve();
    }

    /** ✅ آزادسازیِ موتورها (اختیاری) */
    @PluginMethod
    public void releaseTts(PluginCall call) {
        TtsClient.releaseAll();
        call.resolve();
    }

    // ================================================================
    // ============ مترجمِ آفلاینِ ML Kit =============================
    // ================================================================

    // mlkitStatus({ src, tgt }) → { supported, ready, downloading }
    @PluginMethod
    public void mlkitStatus(final PluginCall call) {
        final String src = call.getString("src", "");
        final String tgt = call.getString("tgt", "");
        final JSObject ret = new JSObject();
        final boolean supported = MlKitTranslator.isSupported(src, tgt);
        ret.put("supported", supported);
        ret.put("downloading", MlKitTranslator.isDownloading(src, tgt));
        if (!supported) { ret.put("ready", false); call.resolve(ret); return; }
        new Thread(new Runnable() {
            @Override public void run() {
                ret.put("ready", MlKitTranslator.refreshReadyBlocking(src, tgt));
                call.resolve(ret);
            }
        }, "mlkit-status").start();
    }

    // mlkitDownload({ src, tgt, wifiOnly }) — وقتی مدل‌ها آماده شد resolve می‌شود
    @PluginMethod
    public void mlkitDownload(final PluginCall call) {
        MlKitTranslator.download(call.getString("src", ""), call.getString("tgt", ""),
                Boolean.TRUE.equals(call.getBoolean("wifiOnly", false)),
                new MlKitTranslator.DoneCb() {
                    @Override public void ok() { call.resolve(); }
                    @Override public void fail(Exception e) { call.reject(String.valueOf(e.getMessage())); }
                });
    }

    // mlkitTranslate({ text, src, tgt }) → { text }
    @PluginMethod
    public void mlkitTranslate(final PluginCall call) {
        String text = call.getString("text", "");
        if (text == null || text.trim().isEmpty()) { call.reject("empty text"); return; }
        MlKitTranslator.translateAsync(call.getString("src", ""), call.getString("tgt", ""), text,
                new MlKitTranslator.Cb() {
                    @Override public void ok(String r) {
                        JSObject ret = new JSObject();
                        ret.put("text", r);
                        call.resolve(ret);
                    }
                    @Override public void fail(Exception e) { call.reject(String.valueOf(e.getMessage())); }
                });
    }

    // mlkitDelete({ lang }) — حذفِ مدلِ یک زبان
    @PluginMethod
    public void mlkitDelete(final PluginCall call) {
        MlKitTranslator.deleteModel(call.getString("lang", ""), new MlKitTranslator.DoneCb() {
            @Override public void ok() { call.resolve(); }
            @Override public void fail(Exception e) { call.reject(String.valueOf(e.getMessage())); }
        });
    }

    // mlkitSetEnabled({ enabled }) — کلیدِ خاموش/روشنِ «اول آفلاین» برای حباب/ذره‌بین
    @PluginMethod
    public void mlkitSetEnabled(PluginCall call) {
        MlKitTranslator.enabled = !Boolean.FALSE.equals(call.getBoolean("enabled", true));
        call.resolve();
    }
}
