import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";

/*
  Призыв и подвал продукта (B4).

  ⚠️ Точка `above-footer` объявлена в корневом `application.gjs` — как и
  `before-main-outlet`, она есть и на страницах админки форума. Видимость
  проверяем тем же реактивным геттером, что и у полосы.

  Все адреса проверены живьём 15.09: отвечают 200. Ключ = сегмент адреса, как и
  в полосе продукта.
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

const DOORS = ["partimento", "harmonization", "scales", "ear-training"];
const PRODUCT = ["partimento", "harmonization", "ear-training", "pricing"];
const REFERENCE = ["scales", "chords", "circle-of-fifths", "blog"];
const LEGAL = ["terms", "privacy-policy", "cookie-policy", "licenses"];

export default class TtFooter extends Component {
  @service router;

  get visible() {
    return !(this.router.currentRouteName || "").startsWith("admin");
  }

  get base() {
    return (settings.product_url || "").replace(/\/+$/, "");
  }

  get prefix() {
    return SITE_PREFIX[I18n.locale] ?? "";
  }

  #link(key, labelKey = `bar.${key.replace(/-/g, "_")}`) {
    return {
      key,
      href: `${this.base}${this.prefix}/${key}`,
      label: i18n(themePrefix(labelKey)),
    };
  }

  get doors() {
    return DOORS.map((key) => ({
      ...this.#link(key),
      desc: i18n(themePrefix(`footer.door_${key.replace(/-/g, "_")}`)),
    }));
  }

  get product() {
    return PRODUCT.map((key) => this.#link(key));
  }

  get reference() {
    return REFERENCE.map((key) => this.#link(key));
  }

  get legal() {
    return LEGAL.map((key) =>
      this.#link(key, `footer.${key.replace(/-/g, "_")}`)
    );
  }

  <template>
    {{#if this.visible}}
      <section class="tt-cta">
        <div class="tt-cta__inner">
          <h2 class="tt-cta__title">{{i18n (themePrefix "footer.cta_title")}}</h2>
          <div class="tt-cta__grid">
            {{#each this.doors as |d|}}
              <a class="tt-cta__door" href={{d.href}}>
                <span class="tt-cta__text">
                  <span class="tt-cta__name">{{d.label}}</span>
                  <span class="tt-cta__desc">{{d.desc}}</span>
                </span>
                <span class="tt-cta__arrow" aria-hidden="true">→</span>
              </a>
            {{/each}}
          </div>
        </div>
      </section>

      <footer class="tt-foot">
        <div class="tt-foot__inner">
          <a class="tt-foot__brand" href={{this.base}}>TerryTrilla</a>

          <div class="tt-foot__cols">
            <div class="tt-foot__col">
              <div class="tt-foot__title">{{i18n (themePrefix "footer.col_product")}}</div>
              {{#each this.product as |l|}}<a href={{l.href}}>{{l.label}}</a>{{/each}}
            </div>
            <div class="tt-foot__col">
              <div class="tt-foot__title">{{i18n (themePrefix "footer.col_reference")}}</div>
              {{#each this.reference as |l|}}<a href={{l.href}}>{{l.label}}</a>{{/each}}
            </div>
            <div class="tt-foot__col">
              <div class="tt-foot__title">{{i18n (themePrefix "footer.col_legal")}}</div>
              {{#each this.legal as |l|}}<a href={{l.href}}>{{l.label}}</a>{{/each}}
            </div>
          </div>

          <div class="tt-foot__note">{{i18n (themePrefix "footer.tagline")}}</div>
        </div>
      </footer>
    {{/if}}
  </template>
}
