import Component from "@glimmer/component";
import { service } from "@ember/service";

/*
  Название клуба рядом со знаком.

  ⚠️ НЕ `home-logo-wrapper`. Та точка — wrapper, у неё допускается ровно ОДНА
  врезка, и её уже занимает плагин чата (`home-logo-wrapper/chat-header-…`).
  Движок в таком случае берёт первую, вторую молча отбрасывает и сыплет
  администратору «Multiple connectors were registered». То есть выбор был не
  «чат или мы», а «кто-то из двоих сломается».

  `header-contents__before` — обычная точка, врезок допускает сколько угодно.
  Название встаёт справа от знака порядком флексбокса, см. tt-header.scss.

  Название берётся из заголовка сайта, поэтому переводить здесь нечего: оно одно
  на всех языках, как и имя продукта.
*/
export default class TtClubName extends Component {
  @service siteSettings;

  <template>
    <span class="tt-club-name">{{this.siteSettings.title}}</span>
  </template>
}
