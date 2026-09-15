import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";

/*
  «Работы в Галерее» в профиле (E5).

  ⚠️ Спрашиваем по ИМЕНИ на форуме: нашего идентификатора тема не знает —
  `external_id` нет ни в `/u/<имя>.json`, ни в админской выдаче. Связь добывает
  наш сервер (`lib/community/resolve-external-id.ts`).

  ⚠️ Правило пустоты (Р-16): нет работ — блока нет вовсе. Не «0 работ», не
  «здесь пока пусто» — ничего. И то же самое при любом отказе: человек, который
  не входил через сайт, не должен видеть ни ошибки, ни следа механизма.
*/
export default class TtWorks extends Component {
  @service siteSettings;

  @tracked works = [];
  @tracked total = 0;

  constructor() {
    super(...arguments);
    this.#load();
  }

  /*
    ⚠️ Спрашиваем по НАШЕМУ идентификатору, а не по имени на форуме. Он приезжает
    полем профиля `tt_uid`: единый вход шлёт его как `custom.tt_uid`, форум
    показывает как публичное поле. Прошлая версия ходила по имени, и нашему
    серверу приходилось добывать связь из АДМИНСКОЙ выдачи форума — ради этого
    на веб-сервере лежал бы ключ с полным доступом. Теперь ключа нет вовсе.
  */
  get externalId() {
    const user = this.args.outletArgs?.model?.user;
    return user?.custom_fields?.tt_uid || null;
  }

  get base() {
    return (settings.product_url || "").replace(/\/+$/, "");
  }

  get prefix() {
    const map = {
      en: "", ru: "/ru", de: "/de", es: "/es", fr: "/fr", ar: "/ar",
      it: "/it", ja: "/ja", ko: "/ko", pl_PL: "/pl", pt_BR: "/pt-br", uk: "/uk",
    };
    return map[I18n.locale] ?? "";
  }

  async #load() {
    const externalId = this.externalId;
    if (!externalId) {
      return;
    }

    try {
      const res = await fetch(
        `${this.base}/api/community/works?external_id=${encodeURIComponent(externalId)}&limit=4`,
        { headers: { Accept: "application/json" } }
      );
      if (!res.ok) {
        return;
      }
      const body = await res.json();
      this.total = body.total || 0;
      this.works = (body.works || []).map((w) => ({
        ...w,
        href: `${this.base}${this.prefix}${w.path}`,
      }));
    } catch {
      // Сеть, CSP, отключённая ручка — блока просто не будет.
    }
  }

  <template>
    {{#if this.works}}
      <div class="tt-works">
        <h3 class="tt-works__title">{{i18n (themePrefix "profile.works")}}</h3>
        <ul class="tt-works__list">
          {{#each this.works as |w|}}
            <li><a href={{w.href}}>{{w.title}}</a></li>
          {{/each}}
        </ul>
        {{#if this.total}}
          <a
            class="tt-works__all"
            href="{{this.base}}{{this.prefix}}/gallery"
          >{{i18n (themePrefix "profile.works_all") count=this.total}}</a>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
