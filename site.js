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

  function getCookieConsent() {
    try {
      return localStorage.getItem('cookie-consent');
    } catch (error) {
      return null;
    }
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
      initAnalytics(); // start analytics if the visitor just accepted
    });
  }

  /* Close the language menu when clicking outside it */
  function initLangSwitcher() {
    document.addEventListener('click', function (event) {
      var openers = document.querySelectorAll('.lang-switcher details[open]');
      Array.prototype.forEach.call(openers, function (d) {
        if (!d.contains(event.target)) d.removeAttribute('open');
      });
    });
  }

  function initCookieSettings() {    var link = document.getElementById('cookie-settings');
    var consent = document.getElementById('cookie-consent');
    if (!link || !consent) return;
    link.addEventListener('click', function (event) {
      event.preventDefault();
      try {
        localStorage.removeItem('cookie-consent');
      } catch (error) {}
      consent.hidden = false;
      consent.scrollIntoView({ block: 'end' });
    });
  }

  /* ------------------------------------------------------------------
   * Contact form (Web3Forms)
   * FORM_ENDPOINT + FORM_ACCESS_KEY drive direct POST submissions.
   * The access key is a *public* key per Web3Forms docs — safe to ship
   * in client-side code. When FORM_ENDPOINT is empty, the form falls back
   * to opening the visitor's email app with a pre-filled message to FORM_TO.
   * ------------------------------------------------------------------ */
  var FORM_ENDPOINT = 'https://api.web3forms.com/submit';
  var FORM_ACCESS_KEY = '5d251189-ca78-4e06-a4f6-ac32afc88f5e';
  var FORM_TO = 'info@aclas.global';

  /* Localised UI strings for the contact form, keyed by <html lang>. */
  var FORM_STRINGS = {
    en: { sending: 'Sending...', send: 'Send Enquiry',
      sent: 'Thank you - your enquiry has been sent. We will reply within 2 working days.',
      error: 'Sorry, something went wrong. Please email us directly at ',
      mailto: 'Opening your email app to send the enquiry...',
      subject: 'Website enquiry' },
    fr: { sending: 'Envoi...', send: 'Envoyer la demande',
      sent: 'Merci \u2014 votre demande a bien \u00e9t\u00e9 envoy\u00e9e. Nous vous r\u00e9pondrons sous 2 jours ouvrables.',
      error: 'D\u00e9sol\u00e9, une erreur s\u2019est produite. Veuillez nous \u00e9crire directement \u00e0 ',
      mailto: 'Ouverture de votre application e-mail pour envoyer la demande...',
      subject: 'Demande via le site web' },
    es: { sending: 'Enviando...', send: 'Enviar consulta',
      sent: 'Gracias \u2014 su consulta ha sido enviada. Le responderemos en un plazo de 2 d\u00edas laborables.',
      error: 'Lo sentimos, algo sali\u00f3 mal. Escr\u00edbanos directamente a ',
      mailto: 'Abriendo su aplicaci\u00f3n de correo para enviar la consulta...',
      subject: 'Consulta del sitio web' },
    hi: { sending: '\u092d\u0947\u091c\u093e \u091c\u093e \u0930\u0939\u093e \u0939\u0948...', send: '\u091c\u093e\u0928\u0915\u093e\u0930\u0940 \u092d\u0947\u091c\u0947\u0902',
      sent: '\u0927\u0928\u094d\u092f\u0935\u093e\u0926 \u2014 \u0906\u092a\u0915\u0940 \u091c\u093e\u0928\u0915\u093e\u0930\u0940 \u092d\u0947\u091c \u0926\u0940 \u0917\u0908 \u0939\u0948\u0964 \u0939\u092e 2 \u0915\u093e\u0930\u094d\u092f\u0926\u093f\u0935\u0938\u094b\u0902 \u0915\u0947 \u092d\u0940\u0924\u0930 \u0909\u0924\u094d\u0924\u0930 \u0926\u0947\u0902\u0917\u0947\u0964',
      error: '\u0915\u094d\u0937\u092e\u093e \u0915\u0930\u0947\u0902, \u0915\u0941\u091b \u0917\u0932\u0924 \u0939\u094b \u0917\u092f\u093e\u0964 \u0915\u0943\u092a\u092f\u093e \u0939\u092e\u0947\u0902 \u0938\u0940\u0927\u0947 \u0907\u0938 \u092a\u0924\u0947 \u092a\u0930 \u0908\u092e\u0947\u0932 \u0915\u0930\u0947\u0902: ',
      mailto: '\u091c\u093e\u0928\u0915\u093e\u0930\u0940 \u092d\u0947\u091c\u0928\u0947 \u0915\u0947 \u0932\u093f\u090f \u0906\u092a\u0915\u093e \u0908\u092e\u0947\u0932 \u0910\u092a \u0916\u094b\u0932\u093e \u091c\u093e \u0930\u0939\u093e \u0939\u0948...',
      subject: '\u0935\u0947\u092c\u0938\u093e\u0907\u091f \u091c\u093e\u0928\u0915\u093e\u0930\u0940' },
    ar: { sending: '\u062c\u0627\u0631\u064d \u0627\u0644\u0625\u0631\u0633\u0627\u0644...', send: '\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0627\u0633\u062a\u0641\u0633\u0627\u0631',
      sent: '\u0634\u0643\u0631\u064b\u0627 \u0644\u0643 \u2014 \u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0627\u0633\u062a\u0641\u0633\u0627\u0631\u0643. \u0633\u0646\u0631\u062f \u062e\u0644\u0627\u0644 \u064a\u0648\u0645\u064a \u0639\u0645\u0644.',
      error: '\u0639\u0630\u0631\u064b\u0627\u060c \u062d\u062f\u062b \u062e\u0637\u0623 \u0645\u0627. \u064a\u0631\u062c\u0649 \u0645\u0631\u0627\u0633\u0644\u062a\u0646\u0627 \u0645\u0628\u0627\u0634\u0631\u0629 \u0639\u0644\u0649 ',
      mailto: '\u062c\u0627\u0631\u064d \u0641\u062a\u062d \u062a\u0637\u0628\u064a\u0642 \u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0644\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0627\u0633\u062a\u0641\u0633\u0627\u0631...',
      subject: '\u0627\u0633\u062a\u0641\u0633\u0627\u0631 \u0645\u0646 \u0627\u0644\u0645\u0648\u0642\u0639' },
    zh: { sending: '\u53d1\u9001\u4e2d...', send: '\u53d1\u9001\u54a8\u8be2',
      sent: '\u8c22\u8c22 \u2014 \u60a8\u7684\u54a8\u8be2\u5df2\u53d1\u9001\u3002\u6211\u4eec\u5c06\u5728 2 \u4e2a\u5de5\u4f5c\u65e5\u5185\u56de\u590d\u3002',
      error: '\u62b1\u6b49\uff0c\u51fa\u9519\u4e86\u3002\u8bf7\u76f4\u63a5\u53d1\u90ae\u4ef6\u81f3 ',
      mailto: '\u6b63\u5728\u6253\u5f00\u60a8\u7684\u90ae\u4ef6\u5e94\u7528\u4ee5\u53d1\u9001\u54a8\u8be2...',
      subject: '\u7f51\u7ad9\u54a8\u8be2' }
  };

  function formLang() {
    var l = (document.documentElement.getAttribute('lang') || 'en').toLowerCase();
    if (l.indexOf('zh') === 0) return 'zh';
    return FORM_STRINGS[l] ? l : 'en';
  }
  function formStr(key) {
    var l = formLang();
    return (FORM_STRINGS[l] && FORM_STRINGS[l][key]) || FORM_STRINGS.en[key];
  }

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
        if (!el.name || el.disabled || el.type === 'submit') return;
        if ((el.type === 'checkbox' || el.type === 'radio') && !el.checked) return;
        data[el.name] = el.value;
      });

      function finish(ok, message) {
        if (btn) { btn.disabled = false; btn.textContent = formStr('send'); }
        showStatus(message, !ok);
        if (ok && FORM_ENDPOINT) form.reset();
      }

      if (btn) { btn.disabled = true; btn.textContent = formStr('sending'); }

      if (FORM_ENDPOINT) {
        var payload = {};
        for (var key in data) {
          if (Object.prototype.hasOwnProperty.call(data, key)) payload[key] = data[key];
        }
        if (FORM_ACCESS_KEY) payload.access_key = FORM_ACCESS_KEY;
        payload.from_name = ((data.first_name || '') + ' ' + (data.last_name || '')).trim() || 'Website visitor';
        payload.subject = formStr('subject') + (data.interest ? ' - ' + data.interest : '') + ' | ACLAS Global';
        fetch(FORM_ENDPOINT, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: JSON.stringify(payload)
        }).then(function (resp) {
          return resp.json().then(
            function (json) { return { ok: resp.ok, json: json }; },
            function () { return { ok: resp.ok, json: null }; }
          );
        }).then(function (result) {
          if (result.ok && (!result.json || result.json.success !== false)) {
            finish(true, formStr('sent'));
          } else {
            finish(false, formStr('error') + FORM_TO + '.');
          }
        }).catch(function () {
          finish(false, formStr('error') + FORM_TO + '.');
        });
      } else {
        var subject = formStr('subject') + (data.interest ? ' - ' + data.interest : '');
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
        if (btn) { btn.disabled = false; btn.textContent = formStr('send'); }
        showStatus(formStr('mailto'), false);
      }
    });
  }

  /* ------------------------------------------------------------------
   * Analytics (GA4)
   * Set GA_MEASUREMENT_ID to your GA4 ID (e.g. 'G-XXXXXXXXXX') to enable.
   * Left empty, no analytics script is loaded.
   * ------------------------------------------------------------------ */
  var GA_MEASUREMENT_ID = 'G-ZLF83C17VS';

  var analyticsLoaded = false;

  function initAnalytics() {
    if (!GA_MEASUREMENT_ID || analyticsLoaded) return;
    if (getCookieConsent() !== 'accepted') return; // respect decline / no choice yet
    analyticsLoaded = true;
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
  initCookieSettings();
  initLangSwitcher();
  initStaticForm();
  initAnalytics();
})();
