import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import TopicList from "discourse/components/topic-list";
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
    const cols = this.args.outletArgs?.model?.curated || [];
    return cols
      .map((col) => ({
        key: col.key,
        href: `/c/${col.slug}`,
        title: i18n(themePrefix(`home.curated_${col.key}`)),
        items: (col.list?.topics || []).slice(0, 4),
      }))
      .filter((col) => col.items.length > 0);
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
                <a class="tt-col__item" href="/t/{{t.slug}}/{{t.id}}">
                  <span class="tt-col__name">{{t.title}}</span>
                  <span class="tt-col__meta">
                    {{i18n (themePrefix "home.replies") count=t.reply_count}}
                  </span>
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
