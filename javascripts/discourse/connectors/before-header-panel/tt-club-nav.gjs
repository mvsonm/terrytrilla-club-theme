import Component from "@glimmer/component";
import { service } from "@ember/service";
import { clubSections } from "../../lib/tt-sections";

/*
  Навигация по разделам клуба — справа, вплотную к переключателю языка.

  ⚠️ Точка `before-header-panel` выбрана не по вкусу, а по разметке ядра
  (`components/header/contents.gjs`): её обёртка `.before-header-panel-outlet`
  стоит НЕПОСРЕДСТВЕННО перед блоком `.panel`, где живут переключатель языка,
  чат, гамбургер и аватар. Никакой другой точки между содержимым шапки и этим
  блоком нет.

  Раньше навигация ехала вместе с названием клуба из `header-contents__before` и
  прижималась к левому краю. Двигать её оттуда вправо пришлось бы порядком
  флексбокса — то есть держать экранный порядок отдельно от порядка в разметке.
  Здесь порядок совпадает, и одной причиной для расхождения меньше.
*/
export default class TtClubNav extends Component {
  @service site;

  get sections() {
    return clubSections(this.site);
  }

  <template>
    {{#if this.sections.length}}
      <nav class="tt-club-nav">
        {{#each this.sections as |s|}}
          <a href={{s.href}}>{{s.name}}</a>
        {{/each}}
      </nav>
    {{/if}}
  </template>
}
