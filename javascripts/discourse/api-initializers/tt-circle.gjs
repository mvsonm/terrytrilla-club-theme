import I18n from "discourse-i18n";
import { apiInitializer } from "discourse/lib/api";
import {
  currentTheme,
  loadCircle,
  productBase,
} from "../lib/tt-circle-runtime";

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

  Загрузчик бандла и схема форума (и почему скрипт вставляется кодом, а не
  разрешением в CSP) — lib/tt-circle-runtime.js: они общие с окном виджетов
  в редакторе (F4).

  ── Жизненный цикл ──
  - `onlyStream`: в предпросмотре редактора ядро не вызывает очистку, и круг
    пересоздавался бы на каждую букву. Там остаётся картинка.
  - Декоратор получает элемент ДО вставки в страницу. Монтирование ждёт, пока
    блок появится на экране (IntersectionObserver): и размеры есть, и бандл
    не качается тем, кто до круга не долистал.
  - Возвращённая функция размонтирует круг при перерисовке и уходе со страницы.
*/

export default apiInitializer((api) => {
  const base = productBase();

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
