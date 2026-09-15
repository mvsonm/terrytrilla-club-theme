import Component from "@glimmer/component";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

/*
  Приглашение в пустом разделе (C6).

  ⚠️ Четыре раздела из шести пусты — это ОСНОВНОЙ вид форума, а не исключение.
  Человек, зашедший в «Теорию», видит там ровно одну служебную тему «About the
  category», заведённую движком, и никакого приглашения: у ядра пустого
  состояния для такого случая нет, потому что формально тема одна есть.

  ⚠️ `discovery-list-area` — WRAPPER-точка: обычная врезка ЗАМЕНИЛА бы список тем.
  Поэтому вставляем через `renderBeforeWrapperOutlet` — она рисует перед
  содержимым точки, не трогая его.
*/
class TtEmptySection extends Component {
  @service discovery;

  get category() {
    return this.discovery.category;
  }

  get visible() {
    return !!this.category && (this.category.topic_count ?? 0) === 0;
  }

  get newTopicHref() {
    return `/new-topic?category=${this.category.slug}`;
  }

  <template>
    {{#if this.visible}}
      <div class="tt-empty">
        <div class="tt-empty__title">
          {{i18n (themePrefix "home.empty_title")}}
        </div>
        <p class="tt-empty__text">{{i18n (themePrefix "home.empty_text")}}</p>
        <a class="tt-empty__cta" href={{this.newTopicHref}}>
          {{i18n (themePrefix "home.section_empty")}}
        </a>
      </div>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderBeforeWrapperOutlet("discovery-list-area", TtEmptySection);
});
