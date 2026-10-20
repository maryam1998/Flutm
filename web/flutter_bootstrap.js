{{flutter_js}}
{{flutter_build_config}}

// بدون صفحه‌ی بارگذاری و بدون هیچ پاک‌سازی/تازه‌سازی خودکار.
// با ?debug=1 زمان مراحل پایین صفحه دیده می‌شود.
// سرویس‌ورکرِ پیش‌فرض فلاتر روشن است تا از بار دوم به بعد فایل‌ها از کش بیایند.
(function () {
  var debug = /[?&]debug\b/.test(location.search);
  var marks = [];
  var logEl;

  function mark(name) {
    marks.push(name + ': ' + (Math.round(performance.now()) / 1000).toFixed(1) + 's');
    if (!debug) return;
    if (!logEl) {
      logEl = document.createElement('pre');
      logEl.style.cssText = 'position:fixed;left:8px;bottom:8px;z-index:99999;margin:0;' +
        'padding:8px 10px;border-radius:10px;background:rgba(0,0,0,.72);color:#fff;' +
        'font:12px/1.5 monospace;direction:ltr;max-width:92vw;white-space:pre-wrap;';
      document.body.appendChild(logEl);
    }
    logEl.textContent = marks.join('\n');
  }

  window.addEventListener('flutter-first-frame', function () { mark('first-frame'); });
  window.addEventListener('maghz-boot', function (e) { mark('dart-' + e.detail); });

  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      mark('main.dart.js');
      var appRunner = await engineInitializer.initializeEngine();
      mark('engine');
      await appRunner.runApp();
    },
  });
})();
