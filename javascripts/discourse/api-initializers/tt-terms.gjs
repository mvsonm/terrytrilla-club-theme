import I18n from "discourse-i18n";
import { apiInitializer } from "discourse/lib/api";
import { CHORDS, SCALES } from "../lib/tt-terms";

/*
  Музыкальные термины в тексте сообщения (D6, решение Р-20).

  ⚠️ Никакого распознавания по шаблону. `C` — это и нота, и язык
  программирования, `Am` бывает переменной, `F` — и нота, и оценка. Автор
  размечает термин САМ, штатным синтаксисом Discourse:

      [wrap=chord]Dm7[/wrap]      [wrap=scale]D dorian[/wrap]

  `[wrap]` переживает очистку разметки и не требует своего парсера — тот же
  приём, что у виджета круга (Р-13).

  ⚠️ Ссылка ставится ТОЛЬКО если такой адрес в справочнике есть: список собран
  из содержания каталога (`lib/tt-terms.js`). Проверка живьём показала, что
  `/chords/dm7` существует, а `/chords/m7` отвечает 404 — ссылка наугад водила бы
  читателя в пустоту. Нет в списке — термин просто оформляется.
*/

const SITE_PREFIX = {
  en: "",
  ru: "/ru",
  de: "/de",
  es: "/es",
  fr: "/fr",
  ar: "/ar",
  it: "/it",
  ja: "/ja",
  ko: "/ko",
  pl_PL: "/pl",
  pt_BR: "/pt-br",
  uk: "/uk",
};

// «D dorian» → «d-dorian», «Dm7» → «dm7», «C#m» → «c-sharp-m»
function slugify(text) {
  return text
    .trim()
    .toLowerCase()
    .replace(/#/g, "-sharp")
    .replace(/♯/g, "-sharp")
    .replace(/b(?=\s|$)/g, "-flat")
    .replace(/♭/g, "-flat")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export default apiInitializer((api) => {
  const base = (settings.product_url || "").replace(/\/+$/, "");

  api.decorateCookedElement(
    (element) => {
      const prefix = SITE_PREFIX[I18n.locale] ?? "";

      element.querySelectorAll("[data-wrap='chord'], [data-wrap='scale']").forEach((node) => {
        if (node.dataset.ttDone) {
          return;
        }
        node.dataset.ttDone = "1";

        const kind = node.dataset.wrap;
        const text = node.textContent.trim();
        const slug = slugify(text);
        const known = kind === "chord" ? CHORDS.has(slug) : SCALES.has(slug);

        node.classList.add("tt-term", `tt-term--${kind}`);

        if (!known) {
          return;
        }

        const link = document.createElement("a");
        link.href = `${base}${prefix}/${kind === "chord" ? "chords" : "scales"}/${slug}`;
        link.className = "tt-term__link";
        link.textContent = text;
        node.replaceChildren(link);
      });
    },
    { id: "tt-terms" }
  );
});
