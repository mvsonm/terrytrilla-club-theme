/*
  Бандл Круга ладов с сайта и схема форума — общие для круга в посте
  (tt-circle.gjs) и предпросмотра в окне виджетов (tt-widget-modal.gjs).
  Один загрузчик — один <script> на страницу, сколько бы кругов ни ожило.

  ── Почему скрипт вставляется кодом, а не разрешением в CSP (F2) ──
  Модификатор `csp_extensions` адреса сайтов НЕ пропускает: ядро
  (`lib/content_security_policy/builder.rb`) выкидывает из script-src всё, что
  не ключевое слово в кавычках. Форум работает с 'strict-dynamic', поэтому
  скрипт, созданный доверенным кодом темы, загружается без разрешения. Цена —
  зависимость от strict-dynamic; сторож в приёмке: «ни одного нарушения CSP».
*/

let loader = null;

export function productBase() {
  return String(settings.product_url || "").replace(/\/+$/, "");
}

export function loadCircle(base = productBase()) {
  if (window.TTCircle) {
    return Promise.resolve(window.TTCircle);
  }
  if (!loader) {
    loader = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = `${base}/embed/circle.js`;
      script.async = true;
      script.onload = () =>
        window.TTCircle
          ? resolve(window.TTCircle)
          : reject(new Error("TTCircle не объявлен"));
      script.onerror = () => reject(new Error("circle.js не загрузился"));
      document.head.appendChild(script);
    });
    loader.catch(() => {
      loader = null;
    });
  }
  return loader;
}

/*
  Схема форума: светлая или тёмная. Спрашиваем не настройку, а то, что
  действительно нарисовано, — фон страницы (--secondary). Настроек у Discourse
  три слоя (схема по умолчанию, выбор человека, системная тема), а фон один.
*/
export function currentTheme() {
  const raw = getComputedStyle(document.documentElement)
    .getPropertyValue("--secondary")
    .trim();
  const hex = raw.replace("#", "");
  if (!/^[0-9a-f]{6}$/i.test(hex)) {
    return "light";
  }
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.5 ? "dark" : "light";
}
