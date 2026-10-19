package com.linglearn.app.overlay;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * متنِ دوزبانه (مثلاً فارسی + انگلیسی) رو به تکه‌های تک‌زبانه می‌شکنه تا هر تکه با «مدلِ خودش» خونده بشه.
 *
 * چرا؟ هر مدلِ Piper فقط یه زبان بلده: اگه جمله‌ی انگلیسی با مدلِ فارسی (یا برعکس) خونده بشه، موقعِ رسیدن به
 * زبانِ دیگه «چرت‌وپرت» می‌گه. TTS خودِ گوشی خودش بر اساسِ خط (script) بینِ زبان‌ها سوئیچ می‌کنه؛ این کلاس
 * همون کار رو برای مدل‌های دانلودی می‌کنه.
 *
 * قانون‌ها:
 *  - حروفِ عربی‌خط (فارسی/عربی/اردو) → زبانِ درخواستی اگه fa/ar/ur باشه، وگرنه fa
 *  - حروفِ لاتین → زبانِ درخواستی اگه لاتین‌خط باشه (en/de/fr/…)، وگرنه en
 *  - سیریلیک → ru ، هان → zh ، دیوانگری → hi
 *  - ارقام، علائمِ نگارشی، فاصله و بقیه‌ی خط‌ها «خنثی» هستن و به تکه‌ی قبلی می‌چسبن
 */
final class TtsSegmenter {

    private TtsSegmenter() {}

    static final class Seg {
        final String lang;
        final String text;
        Seg(String lang, String text) { this.lang = lang; this.text = text; }
    }

    private static final Set<String> LATIN = new HashSet<>(Arrays.asList(
            "en", "de", "fr", "es", "it", "pt", "nl", "tr", "pl", "sv", "no", "da", "fi", "cs", "ro", "hu", "id", "vi"));
    private static final Set<String> ARABIC = new HashSet<>(Arrays.asList("fa", "ar", "ur"));

    /** زبانِ یک حرف یا null اگه خنثی باشه. */
    private static String langOf(int cp, String req) {
        if (!Character.isLetter(cp)) return null;
        if (cp >= 0x0600 && cp <= 0x06FF || cp >= 0x0750 && cp <= 0x077F
                || cp >= 0x08A0 && cp <= 0x08FF || cp >= 0xFB50 && cp <= 0xFDFF
                || cp >= 0xFE70 && cp <= 0xFEFF) {
            return ARABIC.contains(req) ? req : "fa";
        }
        Character.UnicodeScript sc;
        try { sc = Character.UnicodeScript.of(cp); } catch (Throwable t) { return null; }
        switch (sc) {
            case LATIN: return LATIN.contains(req) ? req : "en";
            case CYRILLIC: return "ru";
            case HAN: return "zh";
            case DEVANAGARI: return "hi";
            default: return null;
        }
    }

    static List<Seg> split(String text, String requestedLang) {
        final String req = SherpaModelManager.normalize(requestedLang) == null
                ? "en" : SherpaModelManager.normalize(requestedLang);
        final ArrayList<Seg> out = new ArrayList<>();
        if (text == null || text.isEmpty()) {
            out.add(new Seg(req, text == null ? "" : text));
            return out;
        }
        StringBuilder cur = new StringBuilder();
        String curLang = null;
        for (int i = 0; i < text.length(); ) {
            int cp = text.codePointAt(i);
            int n = Character.charCount(cp);
            String l = langOf(cp, req);
            if (l != null) {
                if (curLang == null) {
                    curLang = l;
                } else if (!curLang.equals(l)) {
                    flush(out, curLang, cur);
                    curLang = l;
                }
            }
            cur.appendCodePoint(cp);
            i += n;
        }
        if (curLang == null) curLang = req;   // اصلاً حرفی نبود (فقط عدد/علامت)
        flush(out, curLang, cur);
        if (out.isEmpty()) out.add(new Seg(req, text));
        return out;
    }

    private static void flush(List<Seg> out, String lang, StringBuilder sb) {
        String t = sb.toString();
        sb.setLength(0);
        if (t.trim().isEmpty()) return;
        out.add(new Seg(lang, t));
    }
}
