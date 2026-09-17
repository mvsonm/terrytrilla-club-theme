import { apiInitializer } from "discourse/lib/api";
import { resolveShareUrl } from "discourse/helpers/share-url";
import I18n from "discourse-i18n";

/*
  «Поделиться» несёт язык читателя (C2 ТЗ-FORUM-LAUNCH, Р-10).

  Адрес темы без параметра отдаёт язык по браузеру, а бот на нём всегда получает
  язык форума (B12). Значит ссылка, которой человек делится, обязана нести язык
  сама: иначе получатель по русской ссылке из чата увидит английский текст — по
  своему браузеру, а не то, что видел отправитель.

  Штатной точки у ядра нет: адрес собирают геттеры `shareUrl` моделей темы и
  поста, и оба — одной строкой через `resolveShareUrl` (helpers/share-url.js).
  Геттеры заменяются штатным `addModelGetter`; базовый адрес считает тот же
  помощник ядра, поэтому `?u=` вошедшего и настройки ядра работают как раньше.
  ⚠️ `api.modifyClass("model:…")` НЕ использовать: для моделей ядро объявило его
  устаревшим (plugin-api.gjs: «Deprecated for `model:` types»).

  Параметр добавляется ТОЛЬКО когда:
    • язык читателя не язык форума по умолчанию — для него параметр не нужен,
      бот получит 301 на адрес без него (B2);
    • тема действительно переведена (`has_localized_content` у темы,
      `is_localized` у поста) — иначе ссылка обещала бы перевод, которого нет;
    • читатель не просил показывать оригиналы (`show_original_content`).

  ⚠️ Кнопка «Поделиться» из выделения текста собирает адрес сама
  (`post-text-selection.gjs`) и здесь НЕ покрывается — известное ограничение ТЗ.

  ⚠️ Точка хрупкая: геттеры ядра могут переехать, и тогда язык молча перестанет
  попадать в ссылку. Сторож — проверка 14 в `spec/acceptance.mjs`: она читает
  живую ссылку кнопки, а не этот файл.
*/

const LOCALE_PARAM = "tl";

function baseLanguage(code) {
  return String(code || "")
    .toLowerCase()
    .replace("-", "_")
    .split("_")[0];
}

function readerLocale(siteSettings) {
  const current = I18n.currentLocale();
  if (!current || baseLanguage(current) === baseLanguage(siteSettings.default_locale)) {
    return null;
  }
  return current;
}

function withLocale(url, locale) {
  if (!url || !locale || new RegExp(`[?&]${LOCALE_PARAM}=`).test(url)) {
    return url;
  }
  return `${url}${url.includes("?") ? "&" : "?"}${LOCALE_PARAM}=${locale}`;
}

function wantsOriginal(user) {
  return Boolean(user?.user_option?.show_original_content ?? user?.show_original_content);
}

/*
  Страница уже на языке читателя, если она ПЕРЕВЕДЕНА на него или НАПИСАНА на
  нём. Второе обязательно: `has_localized_content` у ядра означает «показан
  перевод», и на русской теме русскому читателю он false — ссылка ушла бы без
  языка, хотя отправитель читал по-русски.
*/
function writtenInReaderLanguage(locale, ownLocale) {
  return Boolean(ownLocale) && baseLanguage(ownLocale) === baseLanguage(locale);
}

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.content_localization_enabled) {
    return;
  }

  api.addModelGetter("topic", "shareUrl", function () {
    const url = resolveShareUrl(this.url, this.currentUser);
    const locale = readerLocale(siteSettings);
    if (wantsOriginal(this.currentUser)) {
      return url;
    }
    // Язык оригинала темы ядро в модель не кладёт — берём его у первого поста.
    const ownLocale = this.postStream?.posts?.[0]?.locale;
    if (!this.has_localized_content && !writtenInReaderLanguage(locale, ownLocale)) {
      return url;
    }
    return withLocale(url, locale);
  });

  api.addModelGetter("post", "shareUrl", function () {
    const url = this.customShare || resolveShareUrl(this.url, this.currentUser);
    const locale = readerLocale(siteSettings);
    if (wantsOriginal(this.currentUser)) {
      return url;
    }
    if (!this.is_localized && !writtenInReaderLanguage(locale, this.locale)) {
      return url;
    }
    return withLocale(url, locale);
  });
});
