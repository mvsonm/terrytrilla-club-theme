import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

/*
  Название клуба в шапке (макет Header.dc.html).

  ⚠️ НЕ `home-logo-wrapper`. Та точка — wrapper, у неё допускается ровно ОДНА
  врезка, и её уже занимает плагин чата (`home-logo-wrapper/chat-header-…`).
  Движок в таком случае берёт первую, вторую молча отбрасывает и сыплет
  администратору «Multiple connectors were registered».

  `header-contents__before` — обычная точка. В разметке она идёт ПЕРЕД знаком,
  порядок на экране правит флексбокс (см. tt-header.scss).

  ⚠️ Название короткое — «Клуб», а не заголовок сайта. В макете рядом со знаком
  стоит именно оно: длинное «TerryTrilla Community» вытесняло навигацию разделов
  и дублировало полосу продукта, где имя продукта уже написано.

  Навигация по разделам жила здесь же и прижималась к левому краю. Она переехала
  в отдельную врезку `before-header-panel/tt-club-nav.gjs` — к переключателю
  языка, как в макете. Список разделов у обеих один: `lib/tt-sections.js`.
*/
export default class TtClubName extends Component {
  <template>
    <span class="tt-club-name">{{i18n (themePrefix "header.club")}}</span>
  </template>
}
