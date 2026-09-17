import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

/*
  Согласие с правилами при первом входе (A13 ТЗ-FORUM-LAUNCH, Р-23).

  Механизм — штатный, ядра: обязательное поле профиля типа «галочка» с
  требованием «для всех пользователей» (UserField, requirement = for_all_users).
  Любой вошедший — новый и уже зарегистрированный — перенаправляется на
  /u/<имя>/preferences/profile и не может ничего делать на форуме, пока не
  поставит галочку (ApplicationController#redirect_to_profile_if_required).
  Гость читает без помех. Создаёт поле скрипт
  `terrytrilla-community/scripts/apply-consent-field.rb`.

  Что делает эта врезка: только ПЕРЕВОД. Подпись и описание поля ядро хранит
  одной строкой, на одном языке — у UserField нет локализаций. Поэтому поле
  заведено по-английски, а здесь его подпись и описание подменяются строками
  темы на языке читателя. Описание ядро рисует как HTML (`trustHTML` в
  user-fields/confirm.gjs) — отсюда кликабельные ссылки.

  ⚠️ Поле опознаётся по английскому имени CONSENT_FIELD_NAME — ровно тому, что
  ставит скрипт. Переименовали поле в админке — перевод молча перестанет
  подставляться, и пользователь увидит английский текст (не поломку).

  Пока поля нет, врезка ничего не делает.
*/

const CONSENT_FIELD_NAME = "Community rules";
const TERMS_URL = "https://terrytrilla.com/terms";
const PRIVACY_URL = "https://terrytrilla.com/privacy-policy";

export default apiInitializer((api) => {
  const site = api.container.lookup("service:site");
  const field = (site.user_fields || []).find((f) => f.name === CONSENT_FIELD_NAME);
  if (!field) {
    return;
  }

  const link = (href, text, external) =>
    `<a href="${href}"${external ? ' target="_blank" rel="noopener"' : ""}>${text}</a>`;

  field.name = i18n(themePrefix("consent.label"));
  field.description = i18n(themePrefix("consent.description"), {
    guidelines: link("/guidelines", i18n(themePrefix("consent.guidelines")), false),
    terms: link(TERMS_URL, i18n(themePrefix("consent.terms")), true),
    privacy: link(PRIVACY_URL, i18n(themePrefix("consent.privacy")), true),
  });
});
