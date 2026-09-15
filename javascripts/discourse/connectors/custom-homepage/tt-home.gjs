import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
// ⚠️ Именно `topic-list/list`, а не `topic-list`: второй — устаревшая обёртка,
// движок пишет о ней администратору «код нужно обновить»
// (id:discourse.legacy-topic-list). Сообщение поймано живым просмотром.
import TopicList from "discourse/components/topic-list/list";
import { i18n } from "discourse-i18n";

/*
  Своя главная (C3, C5, C6).

  ⚠️ `custom-homepage` — WRAPPER-точка: врезка допускается ровно одна. Поэтому вся
  главная — один компонент, а не набор вставок: карточки разделов, две колонки
  отобранного и лента последних тем живут здесь вместе.

  Обложку рисует НЕ этот компонент: она штатная (`welcome_banner`), и на маршрут
  `discovery.custom` попадает при `welcome_banner_page_visibility = discovery`
  (welcome-banner.gjs: `case "discovery"` ловит любой `discovery.*`).

  Список тем — компонент ЯДРА. Своя реализация разошлась бы с форумом при первом
  же обновлении: у строки списка есть значки, счётчики, состояния прочитанности и
  массовый выбор, и всё это движок меняет сам.
*/

// Порядок карточек — из макета, а не из порядка разделов в базе.
/*
  Названия языков — на них самих, как в макете: «переведено с 日本語», а не
  «переведено с ja». Коды у Discourse свои: pl_PL, pt_BR.
*/
const LANG_NAMES = {
  en: "English",
  ru: "Русский",
  de: "Deutsch",
  es: "Español",
  fr: "Français",
  ar: "العربية",
  it: "Italiano",
  ja: "日本語",
  ko: "한국어",
  pl_PL: "Polski",
  pt_BR: "Português (BR)",
  uk: "Українська",
};

const SECTIONS = [
  "start-here",
  "questions",
  "theory",
  "show-your-work",
  "ideas",
  "general",
];

export default class TtHome extends Component {
  @service site;
  @service siteSettings;

  get sections() {
    const bySlug = new Map((this.site.categories || []).map((c) => [c.slug, c]));
    return SECTIONS.map((slug) => bySlug.get(slug))
      .filter(Boolean)
      .map((c) => ({
        slug: c.slug,
        name: c.name,
        description: c.description_excerpt || c.description || "",
        count: c.topic_count ?? 0,
        // ⚠️ Пусто — это ОСНОВНОЙ вид: четыре раздела из шести без единой темы.
        // Поэтому у пустого не «0 тем», а приглашение написать первым (C6).
        empty: (c.topic_count ?? 0) === 0,
        href: `/c/${c.slug}/${c.id}`,
        iconId: `tt-${c.slug}`,
      }));
  }

  get curated() {
    const model = this.args.outletArgs?.model;
    const bySlug = new Map((this.site.categories || []).map((c) => [c.slug, c]));

    /*
      ⚠️ У каждого раздела есть служебная тема «About the … category», которую
      движок заводит сам. В `topic_count` она НЕ входит, а в выборку попадает:
      без этой отсечки в подборках висели ровно они, и выглядело это как
      содержание, которого нет.

      ⚠️ Номер берём из `topic_url`, а не из `topic_id`: такого поля у категории
      в клиенте НЕТ. Первая версия сравнивала с undefined и не отсекала ничего.
    */
    const aboutId = Number(
      (bySlug.get("start-here")?.topic_url || "").split("/").pop()
    );

    const starters = (model?.starters?.topics || [])
      .filter((t) => t.id !== aboutId)
      .slice(0, 3)
      .map((t) => ({
        title: t.title,
        href: `/t/${t.slug}/${t.id}`,
        meta: bySlug.get(
          (this.site.categories || []).find((c) => c.id === t.category_id)?.slug
        )?.name || "",
      }));

    /*
      Вторая колонка — витрина главного, ради чего форум и затевался: тема
      написана на чужом языке, а читается на твоём. Признак приходит в самой
      ленте: `fancy_title_localized` = заголовок показан переводом, `locale` =
      язык оригинала. Отдельный запрос не нужен.
    */
    const translated = (model?.latest?.topics || [])
      .filter((t) => t.fancy_title_localized && t.locale)
      .slice(0, 3)
      .map((t) => ({
        // ⚠️ Берём fancy_title, а НЕ title: в title лежит ОРИГИНАЛ, и колонка
        // показывала португальский заголовок там, где лента ниже показывала
        // русский перевод. Признак перевода — fancy_title_localized.
        title: t.fancy_title,
        href: `/t/${t.slug}/${t.id}`,
        meta: i18n(themePrefix("home.translated_from"), {
          lang: LANG_NAMES[t.locale] || t.locale,
        }),
        translated: true,
      }));

    return [
      { key: "start", href: "/c/start-here", title: i18n(themePrefix("home.curated_start")), items: starters },
      { key: "translated", href: "/latest", title: i18n(themePrefix("home.curated_translated")), items: translated },
    ].filter((col) => col.items.length > 0);
  }

  get latest() {
    return this.args.outletArgs?.model?.latest?.topics || [];
  }

  <template>
    <div class="tt-home">
      <section class="tt-home__sections">
        <h2 class="tt-home__title">{{i18n (themePrefix "home.sections")}}</h2>
        <div class="tt-home__grid">
          {{#each this.sections as |s|}}
            <a class="tt-card" href={{s.href}} data-section={{s.slug}}>
              <span class="tt-card__icon">{{icon s.iconId}}</span>
              <span class="tt-card__body">
                <span class="tt-card__name">{{s.name}}</span>
                <span class="tt-card__desc">{{s.description}}</span>
              </span>
              {{#if s.empty}}
                <span class="tt-card__invite">
                  {{i18n (themePrefix "home.section_empty")}}
                </span>
              {{else}}
                <span class="tt-card__count">
                  {{i18n (themePrefix "home.section_topics") count=s.count}}
                </span>
              {{/if}}
            </a>
          {{/each}}
        </div>
      </section>

      {{#if this.curated}}
        <section class="tt-home__curated">
          {{#each this.curated as |col|}}
            <div class="tt-col">
              <a class="tt-col__title" href={{col.href}}>{{col.title}}</a>
              {{#each col.items as |t|}}
                <a class="tt-col__item" href={{t.href}}>
                  <span class="tt-col__name">{{t.title}}</span>
                  <span class="tt-col__meta">{{t.meta}}</span>
                </a>
              {{/each}}
            </div>
          {{/each}}
        </section>
      {{/if}}

      {{#if this.latest}}
        <section class="tt-home__latest">
          <div class="tt-home__head">
            <h2 class="tt-home__title">{{i18n (themePrefix "home.latest")}}</h2>
            <a href="/latest">{{i18n (themePrefix "home.all_topics")}}</a>
          </div>
          <TopicList @topics={{this.latest}} @showPosters={{true}} />
        </section>
      {{/if}}
    </div>
  </template>
}
