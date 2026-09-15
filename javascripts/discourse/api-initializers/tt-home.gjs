import { apiInitializer } from "discourse/lib/api";

/*
  Данные своей главной.

  Маршрут `discovery.custom` создаётся модификатором `custom_homepage` и по
  умолчанию не грузит ничего: его `model()` возвращает `null` через поведенческий
  трансформер `custom-homepage-model` (routes/discovery/custom.js). Тема
  подставляет модель сюда — иначе рисовать на главной было бы нечего.

  ⚠️ Списки грузим ОДНИМ заходом и отдаём готовыми: компонент главной должен
  оставаться без запросов, иначе каждый его перерендер дёргал бы сервер.

  ⚠️ Колонка «Разборы на других языках» отдельного запроса НЕ требует: признак
  перевода приходит в самой ленте — у темы есть `locale` (язык оригинала) и
  `fancy_title_localized` (заголовок показан переводом). Проверено на живых
  темах: две из семи пришли с `pt_BR` и `ja`.
*/
export default apiInitializer((api) => {
  api.registerBehaviorTransformer("custom-homepage-model", ({ context }) => {
    const store = api.container.lookup("service:store");

    const latest = store.findFiltered("topicList", {
      filter: "latest",
      params: { per_page: 20 },
    });

    // «С чего начать» — из раздела `start-here`, как в макете.
    const starters = store
      .findFiltered("topicList", { filter: "c/start-here/l/latest" })
      .catch(() => null);

    return Promise.all([latest, starters]).then(([list, start]) => ({
      latest: list,
      starters: start,
      queryParams: context?.queryParams,
    }));
  });
});
