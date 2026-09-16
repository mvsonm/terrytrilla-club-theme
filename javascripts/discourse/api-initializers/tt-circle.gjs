import I18n from "discourse-i18n";
import { apiInitializer } from "discourse/lib/api";

/*
  Живой Круг ладов в сообщении (ТЗ-THEME, волна F: F2 + F3, решение Р-13).

  Автор пишет штатным [wrap]; закрывающий тег — ОБЯЗАТЕЛЬНО на своей строке:

      [wrap=tt-circle preset=… sound=… scale=harmonicMinor root=A]
      ![Круг ладов: ля гармонический минор](…/api/og?…)
      [/wrap]

  ⚠️ В одну строку `[wrap=…][/wrap]` превращается в <span> внутри абзаца, а не
  в блок. Селектор ниже ловит оба вида, но блочный круг внутри <p> — это
  разметка, которую браузер вправе переложить по-своему.

  ⚠️ Ключи атрибутов — строчные одним словом. Визуальный редактор при записи
  переписывает camelCase в дефисы (`rootNote` → `root-note`).

  Картинка внутри блока — запасной вид (F5): письма, сбой скрипта, предпросмотр
  редактора. Живой круг её прячет, но не удаляет.

  ── Почему скрипт вставляется кодом, а не разрешением в CSP (F2) ──
  Модификатор `csp_extensions` адреса сайтов НЕ пропускает: ядро
  (`lib/content_security_policy/builder.rb`) выкидывает из script-src всё, что
  не ключевое слово в кавычках. Форум работает с 'strict-dynamic', поэтому
  скрипт, созданный доверенным кодом темы, загружается без разрешения. Цена —
  зависимость от strict-dynamic; сторож в приёмке: «ни одного нарушения CSP».

  ── Жизненный цикл ──
  - `onlyStream`: в предпросмотре редактора ядро не вызывает очистку, и круг
    пересоздавался бы на каждую букву. Там остаётся картинка.
  - Декоратор получает элемент ДО вставки в страницу. Монтирование ждёт, пока
    блок появится на экране (IntersectionObserver): и размеры есть, и бандл
    не качается тем, кто до круга не долистал.
  - Возвращённая функция размонтирует круг при перерисовке и уходе со страницы.
*/

let loader = null;

function loadCircle(base) {
  if (window.TTCircle) {
    return Promise.resolve(window.TTCircle);
  }
  if (!loader) {
    loader = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = `${base}/embed/circle.js`;
      script.async = true;
      script.onload = () =>
        window.TTCircle ? resolve(window.TTCircle) : reject(new Error("TTCircle не объявлен"));
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
function currentTheme() {
  const raw = getComputedStyle(document.documentElement).getPropertyValue("--secondary").trim();
  const hex = raw.replace("#", "");
  if (!/^[0-9a-f]{6}$/i.test(hex)) {
    return "light";
  }
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.5 ? "dark" : "light";
}

export default apiInitializer((api) => {
  const base = (settings.product_url || "").replace(/\/+$/, "");

  api.decorateCookedElement(
    (element) => {
      const nodes = element.querySelectorAll("[data-wrap='tt-circle']");
      if (nodes.length === 0) {
        return;
      }

      const cleanups = [];

      nodes.forEach((node) => {
        if (node.dataset.ttCircle) {
          return;
        }
        node.dataset.ttCircle = "waiting";
        node.classList.add("tt-circle-embed");

        let cancelled = false;
        let unmount = null;

        const observer = new IntersectionObserver(
          (entries) => {
            if (!entries.some((entry) => entry.isIntersecting)) {
              return;
            }
            observer.disconnect();
            node.dataset.ttCircle = "loading";

            loadCircle(base)
              .then((circle) =>
                circle.mount(node, {
                  preset: node.dataset.preset || null,
                  sound: node.dataset.sound || null,
                  scale: node.dataset.scale || null,
                  root: node.dataset.root || null,
                  theme: currentTheme(),
                  locale: I18n.locale.replace("_", "-"),
                })
              )
              .then((result) => {
                if (!result.ok) {
                  // Ошибка в разметке — остаётся картинка, автору видно в консоли
                  node.dataset.ttCircle = "error";
                  // eslint-disable-next-line no-console
                  console.warn(`[tt-circle] ${result.reason}`);
                  return;
                }
                if (cancelled) {
                  result.unmount();
                  return;
                }
                unmount = result.unmount;
                node.dataset.ttCircle = "live";
              })
              .catch(() => {
                node.dataset.ttCircle = "error";
              });
          },
          { rootMargin: "200px" }
        );
        observer.observe(node);

        cleanups.push(() => {
          cancelled = true;
          observer.disconnect();
          unmount?.();
          delete node.dataset.ttCircle;
        });
      });

      return () => cleanups.forEach((cleanup) => cleanup());
    },
    { onlyStream: true, id: "tt-circle" }
  );
});
