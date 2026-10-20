{{flutter_js}}
{{flutter_build_config}}

// بدون صفحه‌ی بارگذاری. با ?debug=1 زمان مراحل پایین صفحه دیده می‌شود.
// ضد گیر کردن: اگه سرویس‌ورکرِ نسخه‌ی قبل فایل‌های کهنه بدهد (صفحه‌ی خالیِ همیشگی)،
// این‌جا (قبل از هر چیز) تشخیص می‌دهیم، کش را پاک می‌کنیم و یک‌بار صفحه تازه می‌شود.
(function () {
  var VER = String({{flutter_service_worker_version}});
  var debug = /[?&]debug\b/.test(location.search);
  var marks = [];
  var logEl;
  var firstFrame = false;

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

  function clearAll() {
    var jobs = [];
    try {
      if (navigator.serviceWorker) {
        jobs.push(navigator.serviceWorker.getRegistrations().then(function (rs) {
          return Promise.all(rs.map(function (r) { return r.unregister(); }));
        }));
      }
    } catch (e) {}
    try {
      if (window.caches) {
        jobs.push(caches.keys().then(function (ks) {
          return Promise.all(ks.map(function (k) { return caches.delete(k); }));
        }));
      }
    } catch (e) {}
    return Promise.all(jobs).catch(function () {});
  }

  // ۱) نسخه‌ی سایت عوض شده؟ یک‌بار پاک‌سازی + تازه‌سازی (قبل از بالا آوردن فلاتر)
  try {
    if (localStorage.getItem('maghz_sw_ver') !== VER) {
      localStorage.setItem('maghz_sw_ver', VER);
      clearAll().then(function () { location.reload(); });
      return;
    }
  } catch (e) {}

  window.addEventListener('flutter-first-frame', function () {
    firstFrame = true;
    mark('first-frame');
  });
  window.addEventListener('maghz-boot', function (e) { mark('dart-' + e.detail); });

  // ۲) نگهبان: ۲۵ ثانیه بعد هنوز فریمی نیامده؟ یک‌بار کش را پاک کن و دوباره امتحان کن
  setTimeout(function () {
    if (firstFrame) return;
    try {
      if (sessionStorage.getItem('maghz_wd')) return;
      sessionStorage.setItem('maghz_wd', '1');
    } catch (e) { return; }
    clearAll().then(function () { location.reload(); });
  }, 25000);

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
