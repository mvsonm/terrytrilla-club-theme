import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

/*
  Порог раскрытия профиля (E2).

  Правило пустоты (E1) целиком лежит в CSS: `:has()` прячет блок, в котором нет
  ни одного пункта. Но статистику так не убрать — там пункты ЕСТЬ, просто числа
  в них нули, а разметка ядра нуль от единицы не отличает.

  ⚠️ Здесь нет ни одной точки расширения — страница сводки их не объявляет.
  Поэтому помечаем пункты классом и прячем их стилем, а не удаляем узлы: если
  движок изменит разметку, пометка просто не встанет и профиль вернётся к
  штатному виду. Отказ безопасный.
*/

// «0 дней посещения», «0 получено» — ноль стоит в начале значения.
const ZERO = /^\s*0\s*$/;

function markZeroStats(container) {
  const stats = container.querySelectorAll(".stats-section .user-stat");
  if (!stats.length) {
    return;
  }

  stats.forEach((li) => {
    const value = li.querySelector(".value, .number");
    if (value && ZERO.test(value.textContent)) {
      li.classList.add("tt-zero");
    }
  });
}

function addEmptyNote(container) {
  const sections = [...container.querySelectorAll(".top-section")];
  const visible = sections.filter(
    (s) =>
      s.querySelector("li:not(.tt-zero)") &&
      getComputedStyle(s).display !== "none"
  );

  const existing = container.querySelector(".tt-profile-empty");
  if (visible.length > 0) {
    existing?.remove();
    return;
  }
  if (existing) {
    return;
  }

  const note = document.createElement("p");
  note.className = "tt-profile-empty";
  note.textContent = i18n(themePrefix("profile.empty"));
  container.querySelector("#user-summary, .user-content")?.prepend(note);
}

export default apiInitializer((api) => {
  api.onPageChange(() => {
    const container = document.querySelector(".user-content, #user-summary");
    if (!container) {
      return;
    }
    markZeroStats(container);
    addEmptyNote(container);
  });
});
