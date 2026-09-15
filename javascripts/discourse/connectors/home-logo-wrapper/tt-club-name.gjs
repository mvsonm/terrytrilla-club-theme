import Component from "@glimmer/component";
import { service } from "@ember/service";

/*
  Название клуба рядом со знаком.

  ⚠️ `home-logo-wrapper` — wrapper-точка: `{{yield}}` возвращает штатный
  `<HomeLogo>`. Мы его НЕ заменяем, а дописываем рядом название — по правилу
  движка «переопределение компонентов ядра — последняя мера». Штатный логотип
  умеет и переход на главную, и свёрнутое состояние при прокрутке; своя
  реализация всё это потеряла бы.

  Название берётся из заголовка сайта, поэтому переводить здесь нечего: оно одно
  на всех языках, как и имя продукта.
*/
export default class TtClubName extends Component {
  @service siteSettings;

  <template>
    {{yield}}
    <span class="tt-club-name">{{this.siteSettings.title}}</span>
  </template>
}
