package com.linglearn.app.overlay;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * تشخیصِ زبانِ گفتار از روی «متنِ تشخیص‌داده‌شده» — کاملاً آفلاین و بدونِ وابستگی.
 *
 * زبان‌هایی که در تنظیماتِ اپ هستند: en de fr es it pt nl tr (لاتین) + fa ar ur (عربی‌خط)
 * + ru ja ko zh hi.
 *  - رسم‌الخطِ غیرلاتین (سیریلیک، هانگول، کانا، هان، دیواناگری) تقریباً قطعی است.
 *  - فارسی / عربی / اردو با حرف‌های اختصاصیِ هر کدام جدا می‌شوند (پ چ ژ گ ← فارسی، ة ي ك ← عربی، ٹ ڈ ے ← اردو).
 *  - زبان‌های لاتین با شمارشِ «کلمه‌های پرتکرار» + حرف‌های اختصاصی (ñ ß ç ğ ş ı …) امتیاز می‌گیرند.
 * جوابِ null یعنی «مطمئن نیستم» (متنِ خیلی کوتاه یا امتیازِ نزدیک).
 */
final class LangDetect {

    private LangDetect() {}

    private static final Map<String, Set<String>> STOP = new HashMap<>();

    private static void add(String lang, String csv) {
        Set<String> s = new HashSet<>();
        for (String w : csv.split(",")) { w = w.trim(); if (!w.isEmpty()) s.add(w); }
        STOP.put(lang, s);
    }

    static {
        add("en", "the,and,is,are,was,were,you,your,that,this,with,for,have,has,not,but,what,they,will,would,can,could,it's,i'm,don't,of,to,in,on,at,we,he,she,my,me,do,just,so,be,been,there,about,from,like,going,know,think,because");
        add("de", "der,die,das,und,ist,nicht,ich,du,sie,er,wir,ihr,ein,eine,einen,mit,für,auf,den,dem,des,zu,von,war,es,auch,aber,wie,was,wenn,dass,noch,nur,schon,mal,bin,habe,hat,sind,sich,doch,oder,wird");
        add("fr", "le,la,les,un,une,des,et,est,que,qui,pas,pour,dans,avec,sur,ce,cette,je,tu,il,elle,nous,vous,ils,ne,de,du,au,aux,en,mais,ou,où,plus,être,avoir,suis,sont,c'est,j'ai,n'est,très,fait,comme,tout");
        add("es", "el,la,los,las,un,una,y,es,que,no,por,para,con,en,de,del,se,lo,le,me,te,mi,tu,su,pero,como,más,muy,está,estoy,son,fue,hay,qué,cómo,yo,usted,esto,eso,ya,si,sí,también,porque,cuando");
        add("it", "il,lo,la,gli,le,un,una,e,è,che,non,per,con,di,da,in,su,mi,ti,si,ci,ma,come,più,molto,sono,siamo,questo,quello,anche,perché,cosa,io,tu,lui,lei,noi,voi,loro,ho,hai,ha,ha,del,della,nel,nella");
        add("pt", "o,a,os,as,um,uma,e,é,que,não,por,para,com,em,de,do,da,dos,das,no,na,se,me,te,eu,você,ele,ela,nós,eles,mas,como,mais,muito,está,estou,são,foi,tem,tenho,também,porque,quando,isso,isto,ao");
        add("nl", "de,het,een,en,is,niet,dat,die,ik,je,jij,hij,zij,wij,we,jullie,ze,van,voor,met,op,aan,in,te,maar,ook,als,dan,nog,wel,heb,hebben,ben,bent,zijn,was,wordt,naar,er,om,dit,deze,wat,hoe");
        add("tr", "bir,bu,ve,için,ile,de,da,ne,ben,sen,biz,siz,o,var,yok,çok,daha,gibi,ama,ki,mi,mı,mu,mü,değil,evet,hayır,şey,şu,ben,bunu,onu,olarak,kadar,sonra,her,en,ya,veya,çünkü,nasıl,neden");
    }

    // کلمه‌هایی که تقریباً فقط در همان زبان می‌آیند (وزنِ بیشتر) — زبان‌های هم‌خانواده (es/pt/it/fr) را از هم جدا می‌کنند
    private static final Map<String, Set<String>> STRONG = new HashMap<>();

    private static void strong(String lang, String csv) {
        Set<String> s = new HashSet<>();
        for (String w : csv.split(",")) { w = w.trim(); if (!w.isEmpty()) s.add(w); }
        STRONG.put(lang, s);
    }

    static {
        strong("es", "hola,gracias,señor,señora,pero,muy,también,porque,cuando,está,están,estoy,estás,eres,somos,tengo,tiene,tienes,quiero,quieres,puedo,puedes,vamos,bueno,buenos,buenas,entonces,ahora,aquí,allí,donde,dónde,cómo,qué,quién,cuánto,nada,nunca,siempre,todo,todos,mucho,mucha,casa,tiempo,vez,hoy,mañana,ayer,vuelo,maleta,peso,equipaje,aeropuerto,cena,especial,usted,ustedes,nosotros,ellos,ellas,hacer,hace,hago,dice,dijo,voy,vas,va,van,fue,era,hay,había,sido,estar,ser,tener,ir,decir,también,así,sólo,solo,otra,otro,otros,después,antes,mismo,mejor,peor,pequeño,grande,nuevo,nueva,años,día,días,noche,vida,amigo,amiga,gente,cosa,cosas,lo,las,los,del,al,una,uno,unos,unas,sus,mis,tus,nuestro,esta,este,estos,estas,ese,esa,eso,esto,aquello,sí,no,ya,pues,vale,claro,perdón,disculpe,favor,quizás,tal vez,mientras,aunque,sino,hasta,desde,sobre,entre,hacia,según,sin,con,para,por,muy,más,menos,mucho,poco,bastante,demasiado");
        strong("pt", "obrigado,obrigada,você,vocês,não,também,porque,quando,está,estão,estou,tenho,tem,quero,posso,vamos,bom,boa,então,agora,aqui,onde,como,nada,nunca,sempre,tudo,todos,muito,casa,tempo,vez,hoje,amanhã,ontem,voo,mala,peso,bagagem,aeroporto,jantar,especial,nós,eles,elas,fazer,faz,faço,diz,disse,vou,vai,vão,foi,era,há,havia,sido,estar,ser,ter,ir,dizer,assim,só,outra,outro,depois,antes,mesmo,melhor,pior,pequeno,grande,novo,nova,anos,dia,dias,noite,vida,amigo,amiga,gente,coisa,coisas,uma,uns,umas,seus,meus,teus,nosso,esta,este,esses,essa,isso,isto,sim,já,né,tá,pois,claro,desculpe,favor,talvez,enquanto,embora,mas,até,desde,sobre,entre,segundo,sem,com,para,pelo,pela,mais,menos,pouco,bastante,demais,ção,ções,ões,ão");
        strong("it", "grazie,signore,signora,però,molto,anche,perché,quando,sono,siamo,sei,ho,hai,ha,abbiamo,hanno,voglio,vuoi,posso,puoi,andiamo,buono,buona,allora,adesso,ora,qui,dove,come,niente,mai,sempre,tutto,tutti,molto,casa,tempo,volta,oggi,domani,ieri,volo,valigia,peso,bagaglio,aeroporto,cena,speciale,noi,voi,loro,fare,fa,faccio,dice,disse,vado,vai,va,vanno,era,c'è,ci sono,stato,essere,avere,andare,dire,così,solo,altra,altro,dopo,prima,stesso,meglio,peggio,piccolo,grande,nuovo,nuova,anni,giorno,giorni,notte,vita,amico,amica,gente,cosa,cose,uno,una,gli,degli,delle,della,nel,nella,sul,sulla,sì,già,beh,ecco,scusi,scusa,prego,forse,mentre,anche se,ma,fino,da,su,tra,fra,senza,con,per,più,meno,poco,abbastanza,troppo");
        strong("fr", "bonjour,bonsoir,merci,monsieur,madame,mais,très,aussi,parce,quand,suis,sommes,êtes,sont,ai,as,avons,avez,ont,veux,veux,peux,peut,allons,bon,bonne,alors,maintenant,ici,où,comment,rien,jamais,toujours,tout,tous,beaucoup,maison,temps,fois,aujourd'hui,demain,hier,vol,valise,poids,bagage,aéroport,dîner,spécial,nous,vous,ils,elles,faire,fait,fais,dit,vais,vas,va,vont,était,il y a,été,être,avoir,aller,dire,comme ça,seulement,autre,après,avant,même,mieux,pire,petit,grand,nouveau,nouvelle,ans,jour,jours,nuit,vie,ami,amie,gens,chose,choses,une,des,les,du,au,aux,dans,sur,sous,oui,déjà,bah,voilà,excusez,pardon,peut-être,pendant,bien que,jusqu'à,depuis,entre,sans,avec,pour,plus,moins,peu,assez,trop,c'est,j'ai,n'est,qu'il,qu'elle,l'a,d'un,d'une");
        strong("en", "hello,thanks,thank,please,sorry,because,when,where,what,which,who,how,would,could,should,there,their,they,them,these,those,this,that,with,have,has,had,been,being,was,were,will,shall,going,gonna,wanna,don't,doesn't,didn't,isn't,aren't,wasn't,can't,won't,i'm,i've,i'll,i'd,you're,you've,it's,that's,there's,let's,just,really,very,much,many,some,any,about,after,before,again,still,never,always,every,thing,things,people,time,day,night,home,house,work,flight,suitcase,weight,luggage,airport,dinner,special,know,think,want,need,like,love,make,take,come,give,tell,look,said,says,say");
        strong("de", "hallo,danke,bitte,entschuldigung,aber,sehr,auch,weil,wenn,wann,wo,was,wer,wie,würde,könnte,sollte,haben,hat,hatte,gewesen,wurde,werden,gehen,gehe,gehst,geht,gut,schön,jetzt,hier,nichts,nie,immer,alles,alle,viel,haus,zeit,heute,morgen,gestern,flug,koffer,gewicht,gepäck,flughafen,abendessen,besonders,wir,ihr,sie,machen,macht,mache,sagt,sagte,ist,sind,bin,bist,war,waren,ein,eine,einen,einem,einer,nicht,noch,schon,nur,mal,ja,nein,doch,vielleicht,während,obwohl,bis,seit,über,zwischen,ohne,mit,für,mehr,weniger,wenig,genug,zu,ß,ä,ö,ü");
        strong("nl", "hallo,dank,alstublieft,pardon,maar,heel,ook,omdat,wanneer,waar,wat,wie,hoe,zou,kunnen,hebben,heeft,had,geweest,werd,worden,gaan,ga,gaat,goed,mooi,nu,hier,niets,nooit,altijd,alles,veel,huis,tijd,vandaag,morgen,gisteren,vlucht,koffer,gewicht,bagage,luchthaven,diner,speciaal,wij,jullie,zij,maken,maakt,maak,zegt,zei,is,zijn,ben,bent,was,waren,een,niet,nog,al,alleen,even,ja,nee,toch,misschien,terwijl,hoewel,tot,sinds,over,tussen,zonder,met,voor,meer,minder,weinig,genoeg,te");
        strong("tr", "merhaba,teşekkür,lütfen,pardon,ama,çok,ayrıca,çünkü,ne zaman,nerede,ne,kim,nasıl,olur,olabilir,var,yok,evet,hayır,şimdi,burada,hiçbir,asla,her zaman,hepsi,ev,zaman,bugün,yarın,dün,uçuş,bavul,ağırlık,bagaj,havalimanı,akşam yemeği,özel,biz,siz,onlar,yapmak,yapıyor,diyor,dedi,gidiyorum,gidiyor,iyi,güzel,bir,bu,şu,ve,için,ile,değil,daha,gibi,kadar,sonra,önce,aynı,ğ,ş,ı");
    }

    static {
        // کلمه‌ای که در بیش از یک فهرستِ «اختصاصی» آمده اختصاصی نیست؛ از همه حذف می‌شود
        final Map<String, Integer> cnt = new HashMap<>();
        for (Set<String> st : STRONG.values()) for (String w : st) cnt.put(w, cnt.containsKey(w) ? cnt.get(w) + 1 : 1);
        for (Set<String> st : STRONG.values()) {
            java.util.Iterator<String> it = st.iterator();
            while (it.hasNext()) if (cnt.get(it.next()) > 1) it.remove();
        }
    }

    private static final String[] LATIN = {"en", "de", "fr", "es", "it", "pt", "nl", "tr"};

    /** null = نامطمئن. */
    static String detect(String text) {
        if (text == null) return null;
        final String t = text.trim();
        if (t.length() < 3) return null;

        int fa = 0, ar = 0, ur = 0, arabicLetters = 0;
        int cyr = 0, hangul = 0, kana = 0, han = 0, deva = 0, latin = 0;
        for (int i = 0; i < t.length(); ) {
            int cp = t.codePointAt(i);
            i += Character.charCount(cp);
            if (!Character.isLetter(cp)) continue;
            if (cp >= 0x0600 && cp <= 0x06FF || cp >= 0x0750 && cp <= 0x077F) {
                arabicLetters++;
                switch (cp) {
                    case 0x067E: case 0x0686: case 0x0698: case 0x06AF: case 0x06A9: case 0x06CC:   // پ چ ژ گ ک ی
                        fa++; break;
                    case 0x0629: case 0x064A: case 0x0643: case 0x0649:                              // ة ي ك ى
                        ar++; break;
                    case 0x0679: case 0x0688: case 0x0691: case 0x06BA: case 0x06D2: case 0x06C1: case 0x06BE: // ٹ ڈ ڑ ں ے ہ ھ
                        ur++; break;
                    default: break;
                }
            } else if (cp >= 0x0400 && cp <= 0x04FF) cyr++;
            else if (cp >= 0xAC00 && cp <= 0xD7AF || cp >= 0x1100 && cp <= 0x11FF) hangul++;
            else if (cp >= 0x3040 && cp <= 0x30FF) kana++;
            else if (cp >= 0x4E00 && cp <= 0x9FFF) han++;
            else if (cp >= 0x0900 && cp <= 0x097F) deva++;
            else if (cp < 0x0250) latin++;
        }

        int total = arabicLetters + cyr + hangul + kana + han + deva + latin;
        if (total == 0) return null;

        // ── رسم‌الخطِ غیرلاتین (اگر غالب بود) ──
        if (kana > 0 && (kana + han) * 2 >= total) return "ja";
        if (hangul * 2 >= total) return "ko";
        if (han * 2 >= total) return "zh";
        if (deva * 2 >= total) return "hi";
        if (cyr * 2 >= total) return "ru";
        if (arabicLetters * 2 >= total) {
            if (ur > 0 && ur >= fa && ur >= ar) return "ur";
            if (fa > 0 && fa >= ar) return "fa";
            if (ar > 0) return "ar";
            // حرف‌های اختصاصی ندارد → با کلمه‌های پرتکرار حدس بزن
            return arabicByWords(t);
        }
        if (latin * 2 < total) return null;

        return latinLang(t);
    }

    private static String arabicByWords(String t) {
        int fa = 0, ar = 0, ur = 0;
        for (String w : t.split("[\\s\\p{Punct}\\u060C\\u061F]+")) {
            switch (w) {
                case "است": case "که": case "را": case "با": case "این": case "آن": case "من": case "تو": case "ما":
                case "برای": case "یک": case "هم": case "نه": case "بود": case "می": case "شد": case "هست": case "خیلی":
                    fa++; break;
                case "في": case "على": case "إلى": case "هذا": case "هذه": case "ذلك": case "أن": case "لا":
                case "هو": case "هي": case "كان": case "عن": case "مع":
                    ar++; break;
                case "ہے": case "ہیں": case "کا": case "کی": case "کے": case "اور": case "میں": case "نہیں": case "یہ":
                case "وہ": case "سے": case "کو": case "بھی": case "تھا": case "ہو":
                    ur++; break;
                default: break;
            }
        }
        if (fa == 0 && ar == 0 && ur == 0) return null;
        if (ur > fa && ur > ar) return "ur";
        if (ar > fa) return "ar";
        return "fa";
    }

    private static String latinLang(String t) {
        final String low = t.toLowerCase(Locale.ROOT).replace('\u2019', '\'');
        final String[] words = low.split("[^\\p{L}']+");
        int n = 0;
        for (String w : words) if (!w.isEmpty()) n++;
        if (n == 0) return null;

        final Map<String, Double> score = new HashMap<>();
        for (String l : LATIN) score.put(l, 0.0);

        for (String w : words) {
            if (w.isEmpty()) continue;
            for (String l : LATIN) {
                if (STOP.get(l).contains(w)) score.put(l, score.get(l) + 1.0);
                if (STRONG.get(l).contains(w)) score.put(l, score.get(l) + 1.0);   // کلمه‌ی اختصاصی = وزنِ دو برابر
            }
        }
        // حرف‌های اختصاصی
        bump(score, low, "ß", "de", 2.0);
        bump(score, low, "ä", "de", 1.0); bump(score, low, "ö", "de", 1.0); bump(score, low, "ü", "de", 1.0);
        bump(score, low, "ñ", "es", 2.0); bump(score, low, "¿", "es", 2.0); bump(score, low, "¡", "es", 2.0);
        bump(score, low, "ç", "fr", 0.7); bump(score, low, "è", "fr", 1.0); bump(score, low, "ê", "fr", 1.0);
        bump(score, low, "ù", "fr", 1.0); bump(score, low, "â", "fr", 0.7); bump(score, low, "œ", "fr", 1.5);
        bump(score, low, "ã", "pt", 2.0); bump(score, low, "õ", "pt", 2.0); bump(score, low, "ç", "pt", 0.7);
        bump(score, low, "ğ", "tr", 2.5); bump(score, low, "ş", "tr", 2.5); bump(score, low, "ı", "tr", 2.5);
        bump(score, low, "ö", "tr", 0.5); bump(score, low, "ü", "tr", 0.5);
        bump(score, low, "ì", "it", 1.0); bump(score, low, "ò", "it", 1.0);
        bump(score, low, "ij", "nl", 0.5);
        bump(score, low, "á", "es", 0.6); bump(score, low, "í", "es", 0.6); bump(score, low, "ó", "es", 0.4);
        bump(score, low, "ú", "es", 0.4); bump(score, low, "é", "es", 0.3);
        bump(score, low, "á", "pt", 0.3); bump(score, low, "ê", "pt", 1.0); bump(score, low, "ô", "pt", 1.0);
        bump(score, low, "à", "it", 0.5);

        String best = null; double bs = 0, second = 0;
        for (String l : LATIN) {
            double s = score.get(l);
            if (s > bs) { second = bs; bs = s; best = l; }
            else if (s > second) second = s;
        }
        if (best == null) return n >= 4 ? "en" : null;         // هیچ نشانه‌ای نیست؛ لاتینِ ساده → انگلیسی (پیش‌فرضِ معقول)

        // حداقل شواهد: متنِ کوتاه باید حداقل یک نشانه و برتریِ واضح داشته باشد
        double margin = bs - second;
        if (n <= 3) return (bs >= 1.5 && margin >= 1) ? best : null;
        if (bs < 2 && margin < 1) return null;
        return margin >= 1 || bs >= 2.5 * Math.max(1, second) ? best : null;
    }

    private static void bump(Map<String, Double> score, String low, String ch, String lang, double w) {
        int idx = 0, c = 0;
        while ((idx = low.indexOf(ch, idx)) >= 0) { c++; idx += ch.length(); if (c >= 3) break; }
        if (c > 0) score.put(lang, score.get(lang) + w * c);
    }
}
