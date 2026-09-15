import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

/*
  Подзаголовок обложки (C1).

  Заголовок баннера рисует ядро — он приветствует по имени вошедшего и меняется
  для гостя; трогать его не нужно. Подзаголовок — наш, и он объясняет, ЧТО это
  за место, пока человек не нажал на поиск.
*/
export default class TtCoverSub extends Component {
  <template>
    <span class="tt-cover__sub">{{i18n (themePrefix "home.cover_sub")}}</span>
  </template>
}
