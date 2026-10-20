{{flutter_js}}
{{flutter_build_config}}

// صفحه‌ی بارگذاری + نمایش مرحله و ثانیه (با ?debug=1 زمان هر مرحله هم می‌ماند).
// خودِ بارگذاریِ فلاتر عمداً پیش‌فرض است (هیچ دستکاریِ CanvasKit/پیش‌دانلودی نیست).
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

  // مثل Zflut (که سریع بالا میاد): لودر پیش‌فرضِ فلاتر، CanvasKit از CDN گوگل،
  // و سرویس‌ورکر پیش‌فرض تا بار دوم به بعد همه‌چیز از کشِ خودِ مرورگر بیاد.
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      mark('main.dart.js');
      stage = 'راه‌اندازی موتور';
      var appRunner = await engineInitializer.initializeEngine();
      mark('engine');
      await appRunner.runApp();
    },
  });
})();
