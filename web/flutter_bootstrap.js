{{flutter_js}}
{{flutter_build_config}}

// ── کش هوشمند: سریع و در عین حال همیشه به‌روز ─────────────────────────────
// • سرویس‌ورکر فلاتر روشن است ⇒ از بار دوم به بعد همه‌چیز از کش می‌آید (سریع).
// • هر بیلد یک شناسه‌ی یکتا دارد (FLUTM_BUILD). هم‌زمان با بالا آمدن برنامه،
//   فقط یک درخواست خیلی کوچک (flutter_bootstrap.js، بدون کش) گرفته می‌شود؛ اگر
//   شناسه‌ی سرور با شناسه‌ی همین نسخه فرق داشت یعنی سایت دوباره دیپلوی شده:
//   سرویس‌ورکر و کش قدیمی یک‌بار پاک می‌شود و صفحه خودکار تازه می‌شود.
// • در حالت عادی (نسخه عوض نشده) هیچ تأخیر و هیچ پاک‌سازی‌ای نیست.
// با ?debug=1 زمان مراحل پایین صفحه دیده می‌شود.
(function () {
  var FLUTM_BUILD = String({{flutter_service_worker_version}});

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

  async function wipeAndReload(fresh) {
    try {
      var regs = await navigator.serviceWorker.getRegistrations();
      for (var i = 0; i < regs.length; i++) await regs[i].unregister();
    } catch (e) {}
    try {
      var keys = await caches.keys();
      for (var j = 0; j < keys.length; j++) await caches.delete(keys[j]);
    } catch (e) {}
    // کش HTTP مرورگر (GitHub Pages تا ۱۰ دقیقه کش می‌کند) هم تازه شود
    try { await fetch('flutter_bootstrap.js', { cache: 'reload' }); } catch (e) {}
    try { await fetch(location.pathname, { cache: 'reload' }); } catch (e) {}
    try { sessionStorage.setItem('flutm_reloaded_for', fresh); } catch (e) {}
    location.reload();
  }

  async function checkFresh() {
    try {
      // پارامتر t باعث می‌شود سرویس‌ورکر قدیمی جواب کش‌شده ندهد
      var r = await fetch('flutter_bootstrap.js?t=' + Date.now(), { cache: 'no-store' });
      if (!r.ok) return;
      var m = /FLUTM_BUILD\s*=\s*String\(\s*"?([^")\s]+)/.exec(await r.text());
      if (!m) return;
      var fresh = m[1];
      if (fresh === FLUTM_BUILD) return;
      mark('stale→' + fresh);
      // حلقه‌ی بی‌پایان نداشته باشیم: برای هر نسخه فقط یک‌بار
      try {
        if (sessionStorage.getItem('flutm_reloaded_for') === fresh) return;
      } catch (e) {}
      await wipeAndReload(fresh);
    } catch (e) {
      // آفلاین یا خطا: با همان نسخه‌ی کش‌شده ادامه بده
    }
  }

  window.addEventListener('flutter-first-frame', function () { mark('first-frame'); });
  window.addEventListener('maghz-boot', function (e) { mark('dart-' + e.detail); });

  checkFresh();

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
