import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

/*
  Заголовок и подзаголовок обложки (макет Cover.dc.html).

  ⚠️ Штатный заголовок баннера ЗАМЕНЯЕТСЯ, а не дополняется. Ядро пишет там
  «С возвращением, <имя>!» — приветствие, а не обещание. В макете стоит
  «Спросите о гармонии»: человек, впервые попавший на форум, должен за секунду
  понять, о чём тут спрашивают. Штатный заголовок прячется стилем
  (`tt-cover.scss`), свой рисуется здесь — переопределять строки ядра тема не
  может, а тратить на это правку текстов в админке значит вынести её из git.
*/
export default class TtCoverSub extends Component {
  <template>
    <h1 class="tt-cover__title">{{i18n (themePrefix "home.cover_title")}}</h1>
    <span class="tt-cover__sub">{{i18n (themePrefix "home.cover_sub")}}</span>
  </template>
}
