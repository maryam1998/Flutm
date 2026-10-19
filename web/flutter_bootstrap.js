{{flutter_js}}
{{flutter_build_config}}

// ───────────────────────────────────────────────────────────────
// شروع سریع‌تر:
//  ۱) دانلود main.dart.js بلافاصله شروع می‌شود (قبلاً اول منتظر یک درخواست
//     بررسیِ CanvasKit می‌ماند و بعد شروع می‌کرد).
//  ۲) فایل‌های CanvasKit هم‌زمان با main.dart.js از خودِ سایت گرم می‌شوند
//     (نه از gstatic که روی اینترنت ایران کند/قطعه).
//  ۳) صفحه‌ی بارگذاری مرحله و ثانیه را نشان می‌دهد؛ با باز کردن آدرس با
//     ‎?debug=1‎ زمانِ دقیق هر مرحله هم روی صفحه می‌ماند.
// ───────────────────────────────────────────────────────────────
(function () {
  var boot = document.getElementById('boot');
  var msg = document.getElementById('boot-msg');
  var debug = /[?&]debug\b/.test(location.search);
  var marks = [];
  var stage = 'دانلود برنامه';
  var STAGES = {
    data: 'خواندن اطلاعات',
    ui: 'ساخت صفحه',
  };

  function now() { return Math.round(performance.now()); }
  function mark(name) {
    marks.push(name + ': ' + (now() / 1000).toFixed(1) + 's');
    if (debug) showLog();
  }
  var logEl;
  function showLog() {
    if (!logEl) {
      logEl = document.createElement('pre');
      logEl.style.cssText = 'position:fixed;left:8px;bottom:8px;z-index:99999;margin:0;' +
        'padding:8px 10px;border-radius:10px;background:rgba(0,0,0,.72);color:#fff;' +
        'font:12px/1.5 monospace;direction:ltr;max-width:92vw;white-space:pre-wrap;';
      document.body.appendChild(logEl);
    }
    logEl.textContent = marks.join('\n');
  }

  var tick = setInterval(function () {
    if (!msg) return;
    var s = Math.floor(now() / 1000);
    msg.textContent = stage + '… ' + (s > 0 ? s.toLocaleString('fa') + ' ثانیه' : '');
  }, 500);

  function hideBoot() {
    clearInterval(tick);
    mark('first-frame');
    if (!boot) return;
    boot.classList.add('hide');
    setTimeout(function () { if (boot && boot.parentNode) boot.parentNode.removeChild(boot); boot = null; }, 400);
  }
  window.addEventListener('flutter-first-frame', hideBoot);
  // مرحله‌هایی که خودِ برنامه خبر می‌دهد
  window.addEventListener('maghz-boot', function (e) {
    var k = e.detail;
    mark('dart-' + k);
    if (STAGES[k]) stage = STAGES[k];
  });
  // اگه به هر دلیلی رویداد نیومد، صفحه‌ی بارگذاری برای همیشه نمونه
  setTimeout(hideBoot, 45000);

  // ── CanvasKit محلی: بدون مسدود کردن شروع ──
  var chromiumVariant = !!(window.Intl && Intl.v8BreakIterator && Intl.Segmenter);
  var canvasKitProbe = (async function () {
    try {
      var base = new URL('canvaskit/', document.baseURI).href;
      var r = await fetch(base + 'canvaskit.js', { method: 'HEAD', cache: 'force-cache' });
      if (!r.ok) return null;
      // گرم‌کردن: موتور وقتی بعداً همین فایل را بخواهد از کش مرورگر می‌گیرد
      var v = chromiumVariant ? 'chromium/' : '';
      fetch(base + v + 'canvaskit.js', { cache: 'force-cache' }).catch(function () {});
      fetch(base + v + 'canvaskit.wasm', { cache: 'force-cache' }).catch(function () {});
      return base;
    } catch (e) { return null; }
  })();

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      mark('main.dart.js');
      stage = 'راه‌اندازی موتور';
      var base = await canvasKitProbe;
      var cfg = {};
      if (base) cfg.canvasKitBaseUrl = base;
      var appRunner = await engineInitializer.initializeEngine(cfg);
      mark('engine');
      await appRunner.runApp();
    },
  });
})();
