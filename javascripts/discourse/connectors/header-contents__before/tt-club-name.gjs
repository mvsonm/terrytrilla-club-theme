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

  ⚠️ Название короткое — одно слово, а не заголовок сайта. Длинное «TerryTrilla
  Community» вытесняло навигацию разделов и дублировало полосу продукта, где имя
  продукта уже написано.

  С 17.09.2026 слово — «Сообщество» (C4 ТЗ-FORUM-LAUNCH, Р-11): «клуб» остаётся
  только за закрытой платной частью. Ключ `header.club` не переименован намеренно —
  меняется значение, не адрес строки. «Сообщество» и «Społeczność» втрое длиннее
  «Клуба»: перенос и перелив шапки сторожит проверка 12 приёмки.

  Навигация по разделам жила здесь же и прижималась к левому краю. Она переехала
  в отдельную врезку `before-header-panel/tt-club-nav.gjs` — к переключателю
  языка, как в макете. Список разделов у обеих один: `lib/tt-sections.js`.
*/
export default class TtClubName extends Component {
  <template>
    <span class="tt-club-name">{{i18n (themePrefix "header.club")}}</span>
  </template>
}
