import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";

/*
  Карточка участника при наведении (E4).

  Первую строку — «Writes in» — рисует ЯДРО само: это поле профиля, помеченное
  «показывать в карточке» (E6). Своего кода она не требует и не должна: чем
  меньше мы дублируем штатное, тем меньше ломается при обновлении.

  Вторая строка наша — сколько у человека работ в Галерее.

  ⚠️ Правило пустоты (Р-16): нет работ — строки нет. Ни «0 работ», ни заглушки.
  Пока ручка не выкачена или связи с аккаунтом нет, строка просто не появится.
*/
export default class TtCardWorks extends Component {
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
    const user = this.args.outletArgs?.user;
    return user?.custom_fields?.tt_uid || null;
  }

  get base() {
    return (settings.product_url || "").replace(/\/+$/, "");
  }

  async #load() {
    if (!this.externalId) {
      return;
    }
    try {
      const res = await fetch(
        `${this.base}/api/community/works?external_id=${encodeURIComponent(this.externalId)}&limit=1`,
        { headers: { Accept: "application/json" } }
      );
      if (res.ok) {
        this.total = (await res.json()).total || 0;
      }
    } catch {
      // Молчим: карточка не место для сообщений об отказах.
    }
  }

  <template>
    {{#if this.total}}
      <div class="tt-card-works">
        <a href="{{this.base}}/gallery">
          {{i18n (themePrefix "profile.works_all") count=this.total}}
        </a>
      </div>
    {{/if}}
  </template>
}
