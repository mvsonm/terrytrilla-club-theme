import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";
import { currentTheme, loadCircle, productBase } from "../lib/tt-circle-runtime";
import {
  buildBlock,
  displayRoot,
  ROOTS,
  siteLocale,
  WIDGETS,
} from "../lib/tt-widgets";

/*
  Окно «Виджеты TerryTrilla» в редакторе поста (ТЗ-THEME, F4).

  Всё, что автор раньше набирал руками — id пресета, id звука, имя лада,
  адрес картинки-запаски, — здесь выбирается из списков, а предпросмотр
  показывает живой виджет таким, каким он встанет в статью.

  Слева — виджеты (пока один, Круг ладов), справа — настройка выбранного.
  Окно одно на все виджеты: новый виджет — запись в lib/tt-widgets.js.

  Списки (лады на языке форума, пресеты вида, звуки) отдаёт сайт:
  GET /api/embed/catalog?widget=circle&locale=… Пресеты, помеченные в фабрике
  «для форума», идут первой группой.

  @model.widget   — запись реестра
  @model.values   — начальные значения (при правке — из блока под курсором)
  @model.editing  — правка существующего блока, а не вставка нового
  @model.onApply  — (текст блока) => void
*/

const catalogs = new Map();

function fetchCatalog(widget, locale) {
  const key = `${widget.name}:${locale}`;
  if (!catalogs.has(key)) {
    const url = `${productBase()}/api/embed/catalog?widget=${encodeURIComponent(widget.name)}&locale=${encodeURIComponent(locale)}`;
    const request = fetch(url, { credentials: "omit" }).then((res) => {
      if (!res.ok) {
        throw new Error(`catalog ${res.status}`);
      }
      return res.json();
    });
    // Отказ не кэшируем: «Повторить» должно пойти в сеть заново.
    request.catch(() => catalogs.delete(key));
    catalogs.set(key, request);
  }
  return catalogs.get(key);
}

const t = (key, options) => i18n(themePrefix(`tt_widgets.${key}`), options);

export default class TtWidgetModal extends Component {
  widgets = WIDGETS;
  roots = ROOTS;

  @tracked widget = this.args.model.widget || WIDGETS[0];
  @tracked catalog = null;
  @tracked loadError = false;
  @tracked previewFailed = false;

  @tracked scale = this.args.model.values?.scale || this.widget.defaults.scale;
  @tracked root = this.args.model.values?.root || this.widget.defaults.root;
  @tracked preset = this.args.model.values?.preset || "";
  @tracked sound = this.args.model.values?.sound || "";
  @tracked caption = "";
  @tracked captionTouched = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  get editing() {
    return !!this.args.model.editing;
  }

  get title() {
    return t(this.editing ? "modal_title_edit" : "modal_title");
  }

  @action
  async load() {
    this.loadError = false;
    try {
      const catalog = await fetchCatalog(this.widget, siteLocale(I18n.locale));
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.catalog = catalog;
      // Новый блок получает вид «для форума» (или по умолчанию на сайте) сразу:
      // пустой вид в статье — почти всегда недосмотр, а не выбор.
      if (!this.editing && !this.preset && catalog.presets?.length) {
        const first = catalog.presets.find((p) => p.forum || p.isDefault);
        this.preset = first ? first.id : "";
      }
    } catch {
      if (!this.isDestroying && !this.isDestroyed) {
        this.loadError = true;
      }
    }
  }

  get scaleGroups() {
    const groups = [];
    for (const scale of this.catalog?.scales || []) {
      let group = groups.find((g) => g.notes === scale.notes);
      if (!group) {
        group = { notes: scale.notes, label: t("notes_group", { count: scale.notes }), scales: [] };
        groups.push(group);
      }
      group.scales.push(scale);
    }
    return groups;
  }

  get scaleKnown() {
    return (this.catalog?.scales || []).some((s) => s.id === this.scale);
  }

  get scaleName() {
    return this.catalog?.scales?.find((s) => s.id === this.scale)?.name || this.scale;
  }

  get forumPresets() {
    return (this.catalog?.presets || []).filter((p) => p.forum);
  }

  get otherPresets() {
    return (this.catalog?.presets || []).filter((p) => !p.forum);
  }

  get presetKnown() {
    return !this.preset || (this.catalog?.presets || []).some((p) => p.id === this.preset);
  }

  get soundKnown() {
    return !this.sound || (this.catalog?.sounds || []).some((s) => s.id === this.sound);
  }

  get autoCaption() {
    return t(`widgets.${this.widget.name}.caption`, {
      scale: this.scaleName,
      root: displayRoot(this.root),
    });
  }

  get captionValue() {
    return this.captionTouched ? this.caption : this.autoCaption;
  }

  get canApply() {
    return !!this.catalog && this.scaleKnown;
  }

  @action
  setField(field, event) {
    this[field] = event.target.value;
  }

  @action
  setRoot(root) {
    this.root = root;
  }

  @action
  setCaption(event) {
    this.caption = event.target.value;
    this.captionTouched = true;
  }

  @action
  resetCaption() {
    this.captionTouched = false;
    this.caption = "";
  }

  @action
  apply() {
    if (!this.canApply) {
      return;
    }
    const block = buildBlock(
      this.widget,
      { preset: this.preset, sound: this.sound, scale: this.scale, root: this.root },
      { base: productBase(), locale: this.catalog.locale, caption: this.captionValue }
    );
    this.args.model.onApply(block);
    this.args.closeModal();
  }

  /*
    Живой предпросмотр: тот же бандл, что у круга в посте. Перемонтируется на
    каждую смену лада, тоники, вида или звука; старый круг размонтируется.
  */
  preview = modifier((element, [preset, sound, scale, root]) => {
    let cancelled = false;
    let unmount = null;
    this.previewFailed = false;
    element.replaceChildren();

    loadCircle()
      .then((circle) =>
        circle.mount(element, {
          preset: preset || null,
          sound: sound || null,
          scale,
          root,
          theme: currentTheme(),
          locale: I18n.locale.replace("_", "-"),
        })
      )
      .then((result) => {
        if (!result.ok) {
          throw new Error(result.reason);
        }
        if (cancelled) {
          result.unmount();
          return;
        }
        unmount = result.unmount;
      })
      .catch(() => {
        if (!cancelled) {
          this.previewFailed = true;
        }
      });

    return () => {
      cancelled = true;
      unmount?.();
    };
  });

  <template>
    <DModal
      class="tt-widget-modal"
      @closeModal={{@closeModal}}
      @title={{this.title}}
    >
      <:body>
        <div class="tt-wm">
          <ul class="tt-wm__widgets" role="list">
            {{#each this.widgets as |w|}}
              <li>
                <button
                  type="button"
                  class="tt-wm__widget {{if (eq w.name this.widget.name) '--active'}}"
                  aria-pressed={{if (eq w.name this.widget.name) "true" "false"}}
                  disabled={{this.editing}}
                >
                  {{dIcon w.icon}}
                  <span class="tt-wm__widget-name">{{t (concat "widgets." w.name ".name")}}</span>
                  <span class="tt-wm__widget-desc">{{t (concat "widgets." w.name ".description")}}</span>
                </button>
              </li>
            {{/each}}
          </ul>

          <div class="tt-wm__settings">
            {{#if this.loadError}}
              <div class="tt-wm__error" role="alert">
                <p>{{t "load_error"}}</p>
                <DButton
                  class="btn-default"
                  @action={{this.load}}
                  @translatedLabel={{t "retry"}}
                />
              </div>
            {{else if this.catalog}}
              <label class="tt-wm__field">
                <span class="tt-wm__label">{{t "field.scale"}}</span>
                <select
                  class="tt-wm__select"
                  data-field="scale"
                  {{on "change" (fn this.setField "scale")}}
                >
                  {{#unless this.scaleKnown}}
                    <option value={{this.scale}} selected>{{t "unknown_value" value=this.scale}}</option>
                  {{/unless}}
                  {{#each this.scaleGroups as |group|}}
                    <optgroup label={{group.label}}>
                      {{#each group.scales as |s|}}
                        <option value={{s.id}} selected={{eq s.id this.scale}}>{{s.name}}</option>
                      {{/each}}
                    </optgroup>
                  {{/each}}
                </select>
              </label>

              <div class="tt-wm__field">
                <span class="tt-wm__label">{{t "field.root"}}</span>
                <div class="tt-wm__roots" role="radiogroup" aria-label={{t "field.root"}}>
                  {{#each this.roots as |r|}}
                    <button
                      type="button"
                      role="radio"
                      class="tt-wm__root {{if (eq r this.root) '--active'}}"
                      aria-checked={{if (eq r this.root) "true" "false"}}
                      data-root={{r}}
                      {{on "click" (fn this.setRoot r)}}
                    >{{displayRoot r}}</button>
                  {{/each}}
                </div>
              </div>

              <label class="tt-wm__field">
                <span class="tt-wm__label">{{t "field.preset"}}</span>
                <select
                  class="tt-wm__select"
                  data-field="preset"
                  {{on "change" (fn this.setField "preset")}}
                >
                  <option value="" selected={{eq this.preset ""}}>{{t "preset_none"}}</option>
                  {{#unless this.presetKnown}}
                    <option value={{this.preset}} selected>{{t "unknown_value" value=this.preset}}</option>
                  {{/unless}}
                  {{#if this.forumPresets.length}}
                    <optgroup label={{t "preset_group_forum"}}>
                      {{#each this.forumPresets as |p|}}
                        <option value={{p.id}} selected={{eq p.id this.preset}}>{{p.name}}</option>
                      {{/each}}
                    </optgroup>
                  {{/if}}
                  {{#if this.otherPresets.length}}
                    <optgroup label={{t "preset_group_other"}}>
                      {{#each this.otherPresets as |p|}}
                        <option value={{p.id}} selected={{eq p.id this.preset}}>
                          {{p.name}}{{if p.isDefault (t "preset_site_default")}}
                        </option>
                      {{/each}}
                    </optgroup>
                  {{/if}}
                </select>
                {{#unless this.forumPresets.length}}
                  <span class="tt-wm__hint">{{t "preset_hint"}}</span>
                {{/unless}}
              </label>

              <label class="tt-wm__field">
                <span class="tt-wm__label">{{t "field.sound"}}</span>
                <select
                  class="tt-wm__select"
                  data-field="sound"
                  {{on "change" (fn this.setField "sound")}}
                >
                  <option value="" selected={{eq this.sound ""}}>{{t "sound_none"}}</option>
                  {{#unless this.soundKnown}}
                    <option value={{this.sound}} selected>{{t "unknown_value" value=this.sound}}</option>
                  {{/unless}}
                  {{#each this.catalog.sounds as |s|}}
                    <option value={{s.id}} selected={{eq s.id this.sound}}>{{s.name}}</option>
                  {{/each}}
                </select>
              </label>

              <label class="tt-wm__field">
                <span class="tt-wm__label">{{t "field.caption"}}</span>
                <input
                  type="text"
                  class="tt-wm__input"
                  data-field="caption"
                  value={{this.captionValue}}
                  {{on "input" this.setCaption}}
                />
                <span class="tt-wm__hint">
                  {{t "caption_hint"}}
                  {{#if this.captionTouched}}
                    <button type="button" class="btn-link tt-wm__reset" {{on "click" this.resetCaption}}>{{t "caption_reset"}}</button>
                  {{/if}}
                </span>
              </label>
            {{else}}
              <p class="tt-wm__loading">{{t "loading"}}</p>
            {{/if}}
          </div>

          <figure class="tt-wm__preview">
            {{#if this.scaleKnown}}
              <div
                class="tt-wm__stage"
                {{this.preview this.preset this.sound this.scale this.root}}
              ></div>
            {{/if}}
            <figcaption class="tt-wm__hint">
              {{#if this.previewFailed}}
                {{t "preview_failed"}}
              {{else}}
                {{t (concat "widgets." this.widget.name ".preview_hint")}}
              {{/if}}
            </figcaption>
          </figure>
        </div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary tt-wm__apply"
          @action={{this.apply}}
          @disabled={{if this.canApply false true}}
          @translatedLabel={{if this.editing (t "update") (t "insert")}}
        />
        <DButton
          class="btn-flat"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
