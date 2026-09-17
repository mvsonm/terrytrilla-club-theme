import { apiInitializer } from "discourse/lib/api";
import TtWidgetModal from "../components/tt-widget-modal";
import {
  BLOCK_RE,
  blockAt,
  EDIT_MARK,
  markedBlockRegex,
  parseAttrs,
  valuesFromAttrs,
  widgetByWrap,
} from "../lib/tt-widgets";

/*
  Кнопка «Виджеты TerryTrilla» в редакторе поста (ТЗ-THEME, F4).

  Видна авторам базы знаний (группы из настройки `tt_widgets_groups`) и
  сотрудникам. Одна кнопка на все виджеты: окно показывает список виджетов и
  настройку выбранного.

  ── Вставка и правка ──
  Курсор вне блока — окно вставляет новый блок. Курсор внутри блока виджета —
  окно открывается с его настройками и заменяет ИМЕННО этот блок.

  Вставка — `composer:insert-block`: работает в обоих режимах редактора
  (addText в визуальном берёт только первый абзац блока).

  Правка в двух режимах устроена по-разному, потому что по-разному устроен
  курсор:
  - markdown: курсор — смещение в тексте; блок под ним находит blockAt, а
    replaceText меняет вхождение по порядковому номеру. ⚠️ Номер, а не текст:
    два одинаковых круга в статье различаются только местом.
  - визуальный: курсор стоит в узле редактора, и ядро само говорит, что он в
    [wrap] (`state.inWrap`, `state.wrapAttributes`). Номера блока в markdown
    отсюда не узнать, поэтому узел сначала получает метку штатной командой
    `updateWrap`, а replaceText ищет блок по метке. Замена уносит метку
    вместе со старым блоком.
*/

function allowed(api) {
  const user = api.getCurrentUser();
  if (!user) {
    return false;
  }
  if (user.staff) {
    return true;
  }
  const groups = String(settings.tt_widgets_groups || "")
    .split("|")
    .map((g) => g.trim())
    .filter(Boolean);
  return (user.groups || []).some((g) => groups.includes(g.name));
}

/* Что под курсором: блок нашего виджета или ничего. */
function blockUnderCursor(event) {
  if (event.commands) {
    if (!event.state?.inWrap) {
      return null;
    }
    const attrs = parseAttrs(event.state.wrapAttributes || "");
    const widget = widgetByWrap(attrs.wrap);
    return widget ? { rich: true, widget, attrs } : null;
  }

  const text = event.getText() || "";
  const offset = event.selected?.pre?.length ?? -1;
  const block = blockAt(text, offset);
  return block ? { rich: false, widget: widgetByWrap(block.wrap), attrs: block.attrs, block } : null;
}

/* Строка атрибутов для `updateWrap`: `=tt-circle key=value … ttedit=1`. */
function markedAttributes(attrs) {
  const rest = Object.entries(attrs)
    .filter(([key]) => key !== "wrap" && key !== EDIT_MARK)
    .map(([key, value]) => ` ${key}="${String(value).replace(/"/g, "")}"`)
    .join("");
  return `=${attrs.wrap}${rest} ${EDIT_MARK}=1`;
}

function openWidgets(api, event) {
  const found = blockUnderCursor(event);
  const modal = api.container.lookup("service:modal");

  modal.show(TtWidgetModal, {
    model: {
      widget: found?.widget,
      values: found ? valuesFromAttrs(found.widget, found.attrs) : null,
      editing: !!found,
      onApply: (block) => {
        if (!found) {
          api.container.lookup("service:app-events").trigger("composer:insert-block", block);
          return;
        }
        if (found.rich) {
          event.commands.updateWrap(markedAttributes(found.attrs));
          event.replaceText(block, block, {
            regex: markedBlockRegex(found.widget.wrap),
            index: 0,
          });
          return;
        }
        event.replaceText(found.block.text, block, {
          regex: new RegExp(BLOCK_RE.source, "g"),
          index: found.block.index,
        });
      },
    },
  });
}

export default apiInitializer((api) => {
  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "tt-widgets",
      group: "extras",
      icon: "tt-widgets",
      title: themePrefix("tt_widgets.button_title"),
      preventFocus: true,
      condition: () => allowed(api),
      action: (event) => openWidgets(api, event),
    });
  });
});
