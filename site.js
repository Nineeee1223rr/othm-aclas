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

  /* ------------------------------------------------------------------
   * Contact form
   * Set FORM_ENDPOINT to a form-backend URL (e.g. a Formspree endpoint
   * like 'https://formspree.io/f/your-id') to POST enquiries as JSON.
   * When left empty, the form falls back to opening the visitor's email
   * app with a pre-filled message to FORM_TO.
   * ------------------------------------------------------------------ */
  var FORM_ENDPOINT = '';
  var FORM_TO = 'info@aclas.global';

  function initStaticForm() {
    var form = document.querySelector('form[data-static-form]');
    if (!form) return;

    var status = document.createElement('p');
    status.className = 'form-status';
    status.setAttribute('role', 'status');
    status.hidden = true;
    form.appendChild(status);

    function showStatus(message, isError) {
      status.hidden = false;
      status.textContent = message;
      status.classList.toggle('form-status-error', !!isError);
    }

    form.addEventListener('submit', function (event) {
      event.preventDefault();
      var btn = form.querySelector('[type="submit"]');
      var data = {};
      Array.prototype.forEach.call(form.elements, function (el) {
        if (el.name && !el.disabled && el.type !== 'submit') data[el.name] = el.value;
      });

      function finish(ok, message) {
        if (btn) { btn.disabled = false; btn.textContent = 'Send Enquiry'; }
        showStatus(message, !ok);
        if (ok && FORM_ENDPOINT) form.reset();
      }

      if (btn) { btn.disabled = true; btn.textContent = 'Sending...'; }

      if (FORM_ENDPOINT) {
        fetch(FORM_ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: JSON.stringify(data)
        }).then(function (resp) {
          if (resp.ok) {
            finish(true, 'Thank you - your enquiry has been sent. We will reply within 2 working days.');
          } else {
            finish(false, 'Sorry, something went wrong. Please email us directly at ' + FORM_TO + '.');
          }
        }).catch(function () {
          finish(false, 'Sorry, something went wrong. Please email us directly at ' + FORM_TO + '.');
        });
      } else {
        var subject = 'Website enquiry' + (data.interest ? ' - ' + data.interest : '');
        var lines = [
          'Name: ' + ((data.first_name || '') + ' ' + (data.last_name || '')).trim(),
          'Email: ' + (data.email || ''),
          'Phone: ' + (data.phone || ''),
          'Country: ' + (data.country || ''),
          'Interested in: ' + (data.interest || ''),
          'Programme: ' + (data.programme || ''),
          '',
          data.message || ''
        ];
        window.location.href = 'mailto:' + FORM_TO +
          '?subject=' + encodeURIComponent(subject) +
          '&body=' + encodeURIComponent(lines.join('\n'));
        if (btn) { btn.disabled = false; btn.textContent = 'Send Enquiry'; }
        showStatus('Opening your email app to send the enquiry...', false);
      }
    });
  }

  /* ------------------------------------------------------------------
   * Analytics (GA4)
   * Set GA_MEASUREMENT_ID to your GA4 ID (e.g. 'G-XXXXXXXXXX') to enable.
   * Left empty, no analytics script is loaded.
   * ------------------------------------------------------------------ */
  var GA_MEASUREMENT_ID = '';

  function initAnalytics() {
    if (!GA_MEASUREMENT_ID) return;
    var s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(GA_MEASUREMENT_ID);
    document.head.appendChild(s);
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('js', new Date());
    window.gtag('config', GA_MEASUREMENT_ID);
  }

  initMenu();
  initReveal();
  initCookieConsent();
  initStaticForm();
  initAnalytics();
})();
