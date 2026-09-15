import { apiInitializer } from "discourse/lib/api";

/*
  Данные своей главной.

  Маршрут `discovery.custom` создаётся модификатором `custom_homepage` и по
  умолчанию не грузит ничего: его `model()` возвращает `null` через поведенческий
  трансформер `custom-homepage-model` (routes/discovery/custom.js). Тема
  подставляет модель сюда — иначе рисовать на главной было бы нечего.

  ⚠️ Списки грузим ОДНИМ заходом и отдаём готовыми: компонент главной должен
  оставаться без запросов, иначе каждый его перерендер дёргал бы сервер.
*/
export default apiInitializer((api) => {
  api.registerBehaviorTransformer("custom-homepage-model", ({ context }) => {
    const store = api.container.lookup("service:store");

    const latest = store.findFiltered("topicList", {
      filter: "latest",
      params: { per_page: 10 },
    });

    // Подборки собираем из настоящих разделов, а не из придуманного списка:
    // «С чего начать» — из `start-here`, «Разборы» — из `theory`.
    const curated = ["start-here", "theory"].map((slug) =>
      store
        .findFiltered("topicList", { filter: `c/${slug}/l/latest` })
        .catch(() => null)
    );

    return Promise.all([latest, ...curated]).then(([list, start, deep]) => ({
      latest: list,
      curated: [
        { key: "start", slug: "start-here", list: start },
        { key: "deep", slug: "theory", list: deep },
      ],
      queryParams: context?.queryParams,
    }));
  });
});
