/*
  Виджеты TerryTrilla в статье: реестр и разметка (ТЗ-THEME, F4).

  ⚠️ Модуль ЧИСТЫЙ — ни одного импорта Discourse. Его разбирает
  spec/markup.test.mjs обычным node, без браузера: собрать блок, найти блок под
  курсором, заменить ровно его — это логика, в которой ошибка незаметна глазом
  и дорога (правка не того круга в статье из десяти).

  ── Реестр ──
  Круг ладов — первый виджет, но не последний: на форум встанут все виджеты
  приложения. Новый виджет — запись в WIDGETS (+ его бандл на сайте и строки в
  locales), а кнопка, окно и разбор разметки остаются общими.

  ── Разметка ──
      [wrap=tt-circle preset=… sound=… scale=harmonicMinor root=A]
      ![Круг ладов: …](https://terrytrilla.com/api/embed/circle-image?…)
      [/wrap]

  ⚠️ [/wrap] — на СВОЕЙ строке: в одну строку ядро делает <span> в абзаце.
  ⚠️ Ключи строчные одним словом: визуальный редактор переписывает camelCase
  в дефисы (rootNote → root-note).
  Картинка внутри — запасной вид: письма, сбой скрипта, предпросмотр редактора.
*/

export const WIDGETS = [
  {
    name: "circle",
    wrap: "tt-circle",
    icon: "tt-scale-circle",
    // Порядок — порядок ключей в разметке.
    keys: ["preset", "sound", "scale", "root"],
    defaults: { scale: "ionian", root: "C" },
    image: {
      path: "/api/embed/circle-image",
      keys: ["preset", "scale", "root"],
    },
  },
];

export function widgetByWrap(wrap) {
  return WIDGETS.find((w) => w.wrap === wrap) || null;
}

/*
  Тоники в том написании, которое понимает круг (`parseRoot`): диез и бемоль
  латиницей. Для глаз — со знаками ♯ и ♭.
*/
export const ROOTS = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

export function displayRoot(root) {
  return String(root || "").replace("#", "♯").replace(/^([A-G])b$/, "$1♭");
}

/* Значение атрибута [wrap]: без кавычек, если в нём нет пробела и скобок. */
function attrValue(value) {
  const text = String(value);
  return /^[^\s"'\[\]=]+$/.test(text) ? text : `"${text.replace(/"/g, "")}"`;
}

/* Подпись картинки: квадратные скобки сломали бы markdown-ссылку. */
function altText(text) {
  return String(text || "").replace(/[\[\]\n]/g, " ").trim();
}

export function imageUrl(widget, values, { base, locale }) {
  const params = new URLSearchParams();
  for (const key of widget.image.keys) {
    if (values[key]) {
      params.set(key, values[key]);
    }
  }
  if (locale) {
    params.set("locale", locale);
  }
  return `${String(base || "").replace(/\/+$/, "")}${widget.image.path}?${params}`;
}

/** Готовый блок для вставки в сообщение. */
export function buildBlock(widget, values, { base, locale, caption }) {
  const attrs = widget.keys
    .filter((key) => values[key])
    .map((key) => ` ${key}=${attrValue(values[key])}`)
    .join("");
  return [
    `[wrap=${widget.wrap}${attrs}]`,
    `![${altText(caption)}](${imageUrl(widget, values, { base, locale })})`,
    "[/wrap]",
  ].join("\n");
}

/*
  Атрибуты открывающего тега: `key=value` и `key="value с пробелом"`.
  Первый — `=tt-circle` — имя обёртки.
*/
export function parseAttrs(source) {
  const attrs = {};
  const re = /(?:^|\s)(?:([a-z][a-z0-9_-]*))?=(?:"([^"]*)"|'([^']*)'|([^\s\]]*))/gi;
  let match;
  while ((match = re.exec(source))) {
    const key = match[1] ? match[1].toLowerCase() : "wrap";
    attrs[key] = match[2] ?? match[3] ?? match[4] ?? "";
  }
  return attrs;
}

/* Все блоки виджетов TerryTrilla в тексте, по порядку. */
export const BLOCK_RE = /\[wrap=(tt-[a-z0-9-]+)((?:[^\]\n])*)\]([\s\S]*?)\[\/wrap\]/g;

export function findBlocks(text) {
  const blocks = [];
  const re = new RegExp(BLOCK_RE.source, "g");
  let match;
  while ((match = re.exec(text))) {
    blocks.push({
      index: blocks.length,
      start: match.index,
      end: match.index + match[0].length,
      text: match[0],
      wrap: match[1],
      attrs: parseAttrs(match[2]),
    });
  }
  return blocks;
}

/*
  Блок под курсором (markdown-режим). Курсор на границе — тоже «в блоке»:
  человек обычно ставит его сразу после [/wrap] или перед [wrap.
*/
export function blockAt(text, offset) {
  return (
    findBlocks(text).find(
      (b) => widgetByWrap(b.wrap) && offset >= b.start && offset <= b.end
    ) || null
  );
}

/* Значения блока для окна настройки: только ключи виджета. */
export function valuesFromAttrs(widget, attrs) {
  const values = { ...widget.defaults };
  for (const key of widget.keys) {
    if (attrs[key]) {
      values[key] = attrs[key];
    }
  }
  return values;
}

/*
  Метка для правки в визуальном режиме. Там курсор стоит в узле редактора, а
  не в тексте, и порядкового номера блока в markdown не узнать. Поэтому узел
  сначала получает метку штатной командой `updateWrap`, а замена ищет блок
  ПО МЕТКЕ: одинаковые блоки в статье не перепутаются.
*/
export const EDIT_MARK = "ttedit";

export function markedBlockRegex(wrap) {
  const name = wrap.replace(/[-]/g, "\\-");
  return new RegExp(
    `\\[wrap=${name}(?:[^\\]\\n])*\\s${EDIT_MARK}=["']?1["']?(?=[\\s\\]])(?:[^\\]\\n])*\\][\\s\\S]*?\\[\\/wrap\\]`,
    "g"
  );
}

/* Язык форума → язык подписей сайта: pt_BR → pt-br. Окончательно решает справочник сайта. */
export function siteLocale(forumLocale) {
  return String(forumLocale || "en").toLowerCase().replace(/_/g, "-");
}
