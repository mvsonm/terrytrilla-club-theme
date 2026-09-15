import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

/*
  Объяснение в настройках профиля (E3).

  ⚠️ Имя, почта и аватар приходят с сайта: на форуме включён единый вход, и поля
  в настройках стоят недоступными. Серая форма без единого слова читается как
  поломка — человек думает, что у него что-то сломалось, и идёт спрашивать.
  Одна строка и одна ссылка снимают вопрос целиком.
*/
export default class TtAccountNote extends Component {
  get profileUrl() {
    return `${(settings.product_url || "").replace(/\/+$/, "")}/settings`;
  }

  <template>
    <p class="tt-account-note">
      {{i18n (themePrefix "profile.account_note")}}
      <a href={{this.profileUrl}}>{{i18n (themePrefix "profile.account_link")}}</a>
    </p>
  </template>
}
