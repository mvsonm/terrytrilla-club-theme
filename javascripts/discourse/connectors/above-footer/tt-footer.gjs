import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";

/*
  Призыв и подвал продукта (B4, макет Footer.dc.html).

  ⚠️ Призыв ведёт человека ДАЛЬШЕ ПО ЕГО ВОПРОСУ, а не рекламирует продукт.
  В макете четыре двери: задать вопрос, справочник, Partimento, написать нам.
  Первая моя версия звалась «Попробовать в TerryTrilla» и вела в четыре раздела
  продукта — это реклама на странице, куда человек пришёл за ответом.

  ⚠️ Точка `above-footer` объявлена в корневом `application.gjs` — она есть и на
  страницах админки форума. Видимость проверяет реактивный геттер.
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

/** Языки содержания — те же двенадцать, что у сайта и у форума. */
const LANGS = [
  ["en", "English"],
  ["ru", "Русский"],
  ["de", "Deutsch"],
  ["es", "Español"],
  ["fr", "Français"],
  ["ar", "العربية"],
  ["it", "Italiano"],
  ["ja", "日本語"],
  ["ko", "한국어"],
  ["pl_PL", "Polski"],
  ["pt_BR", "Português (Brasil)"],
  ["uk", "Українська"],
];

/*
  Двери призыва. Первая ведёт на форум (новая тема), остальные — на сайт.
  Все адреса проверены живьём: отвечают 200.
*/
const DOORS = [
  { key: "ask", forum: "/new-topic?category=questions" },
  { key: "library", site: "/scales" },
  { key: "partimento", site: "/partimento" },
  { key: "contact", site: "/support" },
];

/*
  Колонки подвала — состав из строк задания дизайнера. Ключ подписи и адрес
  РАЗДЕЛЕНЫ: «Библиотека» и «Все лады» — разные подписи, и ведут они в разные
  углы справочника. Все адреса проверены живьём: отвечают 200.
*/
const PRODUCT = [
  ["partimento", "/partimento"],
  ["library", "/chords"],
  ["ear_training", "/ear-training"],
  ["metronome", "/metronome"],
  ["tuner", "/tuner"],
  ["gallery", "/gallery"],
];
const MATERIALS = [
  ["blog", "/blog"],
  ["music", "/music-by-terry-trilla"],
  ["circle", "/circle-of-fifths"],
  ["all_scales", "/scales"],
];
const ACCOUNT = [
  { key: "login", forum: "/login" },
  { key: "pricing", site: "/pricing" },
  { key: "rules", forum: "/guidelines" },
  { key: "privacy", site: "/privacy-policy" },
];

const SECTIONS = ["start-here", "questions", "theory", "show-your-work", "ideas", "general"];

export default class TtFooter extends Component {
  @service router;
  @service site;

  get visible() {
    return !(this.router.currentRouteName || "").startsWith("admin");
  }

  get base() {
    return (settings.product_url || "").replace(/\/+$/, "");
  }

  get prefix() {
    return SITE_PREFIX[I18n.locale] ?? "";
  }

  #site(path) {
    return `${this.base}${this.prefix}${path}`;
  }

  #link(key, path) {
    return { key, href: this.#site(path), label: i18n(themePrefix(`footer.${key}`)) };
  }

  get doors() {
    return DOORS.map((d) => ({
      key: d.key,
      href: d.forum ?? this.#site(d.site),
      label: i18n(themePrefix(`footer.door_${d.key}`)),
      desc: i18n(themePrefix(`footer.door_${d.key}_desc`)),
    }));
  }

  get product() {
    return PRODUCT.map(([key, path]) => this.#link(key, path));
  }

  get materials() {
    return MATERIALS.map(([key, path]) => this.#link(key, path));
  }

  /* Разделы форума берём из самого форума: имена уже переведены. */
  get club() {
    const bySlug = new Map((this.site.categories || []).map((c) => [c.slug, c]));
    return SECTIONS.map((slug) => bySlug.get(slug))
      .filter(Boolean)
      .map((c) => ({ key: c.slug, href: `/c/${c.slug}/${c.id}`, label: c.name }));
  }

  get account() {
    return ACCOUNT.map((a) => ({
      key: a.key,
      href: a.forum ?? this.#site(a.site),
      label: i18n(themePrefix(`footer.${a.key}`)),
    }));
  }

  get langs() {
    return LANGS.map(([code, name]) => ({ code, name }));
  }

  get year() {
    return new Date().getFullYear();
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
              <div class="tt-foot__title">{{i18n (themePrefix "footer.col_materials")}}</div>
              {{#each this.materials as |l|}}<a href={{l.href}}>{{l.label}}</a>{{/each}}
            </div>
            <div class="tt-foot__col">
              <div class="tt-foot__title">{{i18n (themePrefix "footer.col_club")}}</div>
              {{#each this.club as |l|}}<a href={{l.href}}>{{l.label}}</a>{{/each}}
            </div>
            <div class="tt-foot__col">
              <div class="tt-foot__title">{{i18n (themePrefix "footer.col_account")}}</div>
              {{#each this.account as |l|}}<a href={{l.href}}>{{l.label}}</a>{{/each}}
            </div>
          </div>

          <div class="tt-foot__langs">
            <div class="tt-foot__title">{{i18n (themePrefix "footer.langs_title")}}</div>
            <div class="tt-foot__langs-row">
              {{#each this.langs as |l|}}<span>{{l.name}}</span>{{/each}}
            </div>
          </div>

          <div class="tt-foot__note">
            <span>© {{this.year}} TerryTrilla</span>
            <span>{{i18n (themePrefix "footer.domain")}}</span>
          </div>
        </div>
      </footer>
    {{/if}}
  </template>
}
