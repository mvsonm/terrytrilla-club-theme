import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";

/*
  Полоса продукта над форумом.

  ⚠️ Точка — `above-site-header`, а НЕ `before-main-outlet`. В корневом шаблоне
  `application.gjs` они стоят по разные стороны шапки: `above-site-header` (стр. 51)
  выше `<GlimmerSiteHeader>`, а `before-main-outlet` (стр. 102) уже внутри области
  содержимого. В первой редакции стояла вторая — и полоса продукта оказалась ПОД
  шапкой форума, посреди страницы.

  ⚠️ Точка корневая, то есть есть и в админке форума: маршрут проверяем ниже.

  Проверку делает геттер `visible`, а не `shouldRender`: `shouldRender` —
  фильтр на момент отрисовки аутлета (`plugin-connectors.js`:
  `connectorClass?.shouldRender(args, context, owner)`), а корневой аутлет
  отрисовывается один раз за загрузку. Переход из темы в админку его бы не
  переспросил. Геттер по `router.currentRouteName` реактивен и переживает
  переходы.
*/

// Префикс адреса на сайте по коду локали форума.
//
// ⚠️ У сайта префикс «по необходимости»: у английского его НЕТ. Склейка
// `/${locale}` даёт лишний 308 — это уже стоило разбора, см. в монорепо
// `docs/i18n/ROADMAP-LOCALE.md`. И коды у Discourse свои: `pl_PL`, `pt_BR`.
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

export default class TtProductBar extends Component {
  @service router;
  @service currentUser;

  get visible() {
    const route = this.router.currentRouteName || "";
    return !route.startsWith("admin");
  }

  get prefix() {
    return SITE_PREFIX[I18n.locale] ?? "";
  }

  get base() {
    return (settings.product_url || "").replace(/\/+$/, "");
  }

  // Ключ раздела совпадает с сегментом адреса на сайте: partimento → /partimento.
  // Подпись берём из строк темы, поэтому ключ приводим к виду bar.ear_training.
  // ⚠️ Настройка типа list приходит СТРОКОЙ «a|b|c», а не массивом. Вызов
  // .filter на ней бросал TypeError, и падение ломало отрисовку ВСЕЙ области
  // содержимого: на экране оставалась шапка и пустота, а список тем исчезал.
  #items(list) {
    return String(list || "")
      .split("|")
      .filter(Boolean)
      .map((key) => ({
        key,
        href: `${this.base}${this.prefix}/${key}`,
        label: i18n(themePrefix(`bar.${key.replace(/-/g, "_")}`)),
      }));
  }

  get sections() {
    return this.#items(settings.product_bar_links);
  }

  get moreSections() {
    return this.#items(settings.product_bar_more);
  }

  get signInHref() {
    return settings.sign_in_url;
  }

  <template>
    {{#if this.visible}}
      <div class="tt-bar">
        <div class="tt-bar__inner">
          <a class="tt-bar__brand" href={{this.base}}>TerryTrilla</a>

          <nav class="tt-bar__nav">
            {{#each this.sections as |s|}}
              <a class="tt-bar__link" href={{s.href}}>{{s.label}}</a>
            {{/each}}

            {{#if this.moreSections}}
              <details class="tt-bar__more">
                <summary>{{i18n (themePrefix "bar.more")}}</summary>
                <div class="tt-bar__menu">
                  {{#each this.moreSections as |s|}}
                    <a href={{s.href}}>{{s.label}}</a>
                  {{/each}}
                </div>
              </details>
            {{/if}}
          </nav>

          <div class="tt-bar__end">
            {{#if this.currentUser}}
              <a class="tt-bar__link" href={{this.base}}>
                {{i18n (themePrefix "bar.account")}}
              </a>
            {{else}}
              <a class="tt-bar__cta" href={{this.signInHref}}>
                {{i18n (themePrefix "bar.login")}}
              </a>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
