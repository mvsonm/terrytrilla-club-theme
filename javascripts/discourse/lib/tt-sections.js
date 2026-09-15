/*
  Разделы клуба для шапки — общий список для двух врезок.

  Название клуба живёт в `header-contents__before` (слева, рядом со знаком), а
  навигация — в `before-header-panel` (справа, вплотную к переключателю языка).
  Это ДВЕ разные точки расширения, то есть два компонента, и список разделов у
  них обязан быть один: два одинаковых массива в двух файлах однажды разъедутся,
  и заметит это только тот, кто сверит шапку с макетом.
*/

// Порядок — из макета, а не из порядка в базе.
export const SECTION_SLUGS = [
  "start-here",
  "questions",
  "theory",
  "show-your-work",
  "ideas",
  "general",
];

/*
  ⚠️ Адрес раздела собирается как `/c/<slug>/<id>` — с числовым идентификатором.
  Одного slug движку мало: без id ссылка ведёт на поиск по разделам, а не в сам
  раздел.
*/
export function clubSections(site) {
  const bySlug = new Map((site?.categories || []).map((c) => [c.slug, c]));
  return SECTION_SLUGS.map((slug) => bySlug.get(slug))
    .filter(Boolean)
    .map((c) => ({ name: c.name, href: `/c/${c.slug}/${c.id}` }));
}
