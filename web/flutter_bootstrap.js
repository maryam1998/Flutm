{{flutter_js}}
{{flutter_build_config}}

// ───────────────────────────────────────────────────────────────
// چرا این فایل هست؟
//  ۱) CanvasKit (موتور رسم فلاتر، حدود ۱.۵–۲ مگابایت) به‌طور پیش‌فرض از www.gstatic.com
//     دانلود می‌شه. روی اینترنت ایران این دانلود کند یا قطعه و همون «لود خیلی کند» بود.
//     اینجا اگه نسخه‌ی خودِ سایت (پوشه‌ی canvaskit کنار برنامه) موجود باشه از همون استفاده می‌شه.
//  ۲) صفحه‌ی بارگذاری (#boot) تا اولین فریم فلاتر نمایش داده می‌شه.
// ───────────────────────────────────────────────────────────────
(function () {
  var boot = document.getElementById('boot');
  var msg = document.getElementById('boot-msg');

  function hideBoot() {
    if (!boot) return;
    boot.classList.add('hide');
    setTimeout(function () { if (boot && boot.parentNode) boot.parentNode.removeChild(boot); boot = null; }, 400);
  }
  window.addEventListener('flutter-first-frame', hideBoot); // وب: اولین فریم = خودِ برنامه
  // اگه به هر دلیلی رویداد نیومد، صفحه‌ی بارگذاری برای همیشه نمونه
  setTimeout(hideBoot, 45000);

  async function localCanvasKitBase() {
    try {
      var base = new URL('canvaskit/', document.baseURI).href;
      var r = await fetch(base + 'canvaskit.js', { method: 'HEAD', cache: 'force-cache' });
      return r.ok ? base : null;
    } catch (e) { return null; }
  }

  localCanvasKitBase().then(function (base) {
    var config = {};
    if (base) config.canvasKitBaseUrl = base;
    _flutter.loader.load({
      config: config,
      onEntrypointLoaded: async function (engineInitializer) {
        if (msg) msg.textContent = 'در حال راه‌اندازی…';
        var appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
      },
    });
  });
})();
