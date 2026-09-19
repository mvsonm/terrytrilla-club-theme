import { apiInitializer } from "discourse/lib/api";

/*
  Значок вкладки следует за АКТИВНОЙ схемой страницы (B18-бис).

  Сервер печатает три значка: базовый (без условия — его читают Google и Firefox)
  и два с `media` — светлый и тёмный. Этого хватает ровно на загрузку страницы.

  ⚠️ `media` у `<link rel=icon>` браузер перечитывает только при загрузке: схема
  сменилась — значок остался прежним. Именно это заметил владелец 19.09: «смена
  фавикона при смене темы не сделана». Лечится сменой `href` у базового тега —
  её Chrome отслеживает.

  Как определяется активная схема — по тому же, по чему её определяет сам
  Discourse: две таблицы стилей с классами `light-scheme` и `dark-scheme`.
  Источников схемы два: медиазапрос `(prefers-color-scheme: …)` при «как в
  системе» и `media: all/none` — так сервер закрепляет схему при куке
  `forced_color_mode` и так же повёл бы себя переключатель интерфейса, если его
  включат (на 19.09 `interface_color_selector = disabled`). Поэтому спрашиваем не
  настройку и не класс на `<html>` (их у гостя нет вовсе — замер 19.09), а
  ПРИМЕНЕНА ли таблица: `media === "all"` либо запрос совпадает.

  Пересчёт нужен на оба события: смену системной схемы (`matchMedia`) и правку
  `media` (`MutationObserver` на тех же ссылках).

  ⚠️ Адреса значков НЕ зашиты: берутся из тегов, которые напечатал сервер. Иначе
  тема и плагин разошлись бы при первой же замене картинки.
*/
export default apiInitializer(() => {
  const применена = (ссылка) => {
    if (!ссылка) {
      return false;
    }
    const media = (ссылка.getAttribute("media") || "").trim();
    if (!media || media === "all") {
      return true;
    }
    if (media === "none") {
      return false;
    }
    return window.matchMedia(media).matches;
  };

  const тёмнаяАктивна = () => {
    const светлая = document.querySelector("link.light-scheme");
    const тёмная = document.querySelector("link.dark-scheme");
    if (применена(тёмная) && !применена(светлая)) {
      return true;
    }
    if (применена(светлая) && !применена(тёмная)) {
      return false;
    }
    // Обе (или ни одной) — решает система: так ведёт себя и сам браузер.
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
  };

  const варианты = () => {
    const все = [...document.querySelectorAll('link[rel~="icon"][media]')];
    return {
      светлый: все.find((l) => (l.getAttribute("media") || "").includes("light")),
      тёмный: все.find((l) => (l.getAttribute("media") || "").includes("dark")),
    };
  };

  const обновить = () => {
    const { светлый, тёмный } = варианты();
    const нужный = тёмнаяАктивна() ? тёмный : светлый;
    if (!нужный) {
      return;
    }
    const базовый = [...document.querySelectorAll('link[rel~="icon"]')].find(
      (l) => !l.getAttribute("media")
    );
    if (!базовый || базовый.href === нужный.href) {
      return;
    }
    // Меняем адрес у базового тега: Chrome перечитывает значок при смене href.
    базовый.href = нужный.href;
  };

  обновить();

  window
    .matchMedia("(prefers-color-scheme: dark)")
    .addEventListener("change", обновить);

  const наблюдатель = new MutationObserver(обновить);
  for (const ссылка of document.querySelectorAll(
    "link.light-scheme, link.dark-scheme"
  )) {
    наблюдатель.observe(ссылка, { attributes: true, attributeFilter: ["media"] });
  }
});
