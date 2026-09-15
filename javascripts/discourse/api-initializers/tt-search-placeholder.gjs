import { apiInitializer } from "discourse/lib/api";

/*
  Подсказка в поле поиска на обложке (макет Cover.dc.html).

  Ядро берёт её из ключа `welcome_banner.search_placeholder` — «Искать». В макете
  стоит пример вопроса: «Например: почему V ступень в миноре мажорная». Разница
  не косметическая: пустое поле с надписью «Искать» человек читает как поиск по
  сайту, а пример показывает, ЧТО здесь вообще спрашивают.

  ⚠️ Меняем ШТАТНЫМ трансформером значения, а не правкой текстов в админке:
  правка в админке живёт вне git и исчезает из истории (Р-4). Ключ подставляем
  свой, из строк темы.

  ⚠️ Только на обложке: у поиска в шапке своё место и свой смысл, подменять его
  примером вопроса не надо — там ищут по уже прочитанному.
*/
export default apiInitializer((api) => {
  api.registerValueTransformer(
    "search-menu-input-placeholder",
    ({ value, context }) =>
      context?.location === "welcome-banner"
        ? themePrefix("home.cover_placeholder")
        : value
  );
});
