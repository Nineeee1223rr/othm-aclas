(function () {
  document.documentElement.classList.add('js-enabled');

  function initMenu() {
    var toggle = document.querySelector('.menu-toggle');
    var nav = document.getElementById('mainNav');
    if (!toggle || !nav) return;

    toggle.addEventListener('click', function () {
      var isOpen = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', String(isOpen));
    });
  }

  function initReveal() {
    var revealItems = document.querySelectorAll('.feat, .card-outer, .quote, .section h2');
    if (!revealItems.length) return;

    if (!('IntersectionObserver' in window)) {
      revealItems.forEach(function (el) { el.classList.add('visible'); });
      return;
    }

    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });

    revealItems.forEach(function (el) {
      el.classList.add('reveal');
      observer.observe(el);
    });
  }

  function initCookieConsent() {
    var consent = document.getElementById('cookie-consent');
    if (!consent) return;

    try {
      if (!localStorage.getItem('cookie-consent')) {
        consent.hidden = false;
      }
    } catch (error) {
      consent.hidden = false;
    }

    consent.addEventListener('click', function (event) {
      var button = event.target.closest('[data-cookie-choice]');
      if (!button) return;

      try {
        localStorage.setItem('cookie-consent', button.getAttribute('data-cookie-choice'));
      } catch (error) {}
      consent.hidden = true;
    });
  }

  initMenu();
  initReveal();
  initCookieConsent();
})();
