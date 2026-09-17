/*
  ПРИЁМКА ПОВЕДЕНИЕМ (G3) — одиннадцать проверок §6 ТЗ против ЖИВОГО форума.

  ⚠️ Почему не `discourse_theme rspec .`, как написано в ТЗ. Замер боевого
  контейнера 15.09: `rspec` не установлен вовсе (production-сборка идёт без
  тестовой группы), браузера для системных тестов нет, тестовой базы нет.
  Поставить всё это на живой форум — значит завести на нём среду разработки;
  цена выше пользы. Путь ТЗ остаётся верным для отдельного экземпляра
  Discourse; когда он появится, эти же проверки переносятся построчно.

  Что проверка ЛОВИТ: поломку после обновления форума, правки темы, смены
  настроек — то есть ровно то, ради чего §6 и написан.

  ── ДО выката (16.09.2026) ─────────────────────────────────────────────────

  Раньше здесь стояло «поломку ДО выката не ловит, нужен отдельный экземпляр».
  Отдельный экземпляр не понадобился: у самого Discourse есть предпросмотр
  темы — `?preview_theme_id=N`. Копия темы для разработки привязана к ветке
  `staging` того же репозитория, и те же самые проверки гоняются по ней, не
  трогая того, что видит посетитель.

  ⚠️ Предпросмотр работает ТОЛЬКО у сотрудника. Значит нужен сеанс, и он
  передаётся ФАЙЛОМ, а не переменной окружения и не аргументом команды:
  аргументы видны в `ps` любому на машине.

  Запуск:
    node spec/acceptance.mjs                       — по боевой теме
    TT_PREVIEW_THEME_ID=3 TT_SESSION_FILE=/path/f \
      node spec/acceptance.mjs                     — по теме из ветки staging

  Нужен playwright и доступ к https://terrytrilla.club

  ⚠️ У каждой проверки, где «ничего не нашлось» могло бы сойти за успех, стоит
  КОНТРОЛЬ — утверждение, обязанное быть истинным. Без него пустой результат
  означает лишь «искали не там»: на этом я уже принимал сломанный пробник за
  исправную тему.
*/

import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';

const БАЗА = process.env.TT_FORUM || 'https://terrytrilla.club';
const итоги = [];

/*
  Предпросмотр темы: номер темы и сеанс сотрудника.

  ⚠️ Сеанс читается ИЗ ФАЙЛА и никогда не печатается. Правило не формальное:
  аргументы команды видны в `ps` всем пользователям машины, а заголовок запроса
  утекает при первом же переходе на чужой домен.
*/
const ПРЕВЬЮ = process.env.TT_PREVIEW_THEME_ID || null;
let СЕАНС = null;
if (process.env.TT_SESSION_FILE) {
  СЕАНС = readFileSync(process.env.TT_SESSION_FILE, 'utf8').trim();
  if (!СЕАНС) throw new Error('файл сеанса пуст');
}
if (ПРЕВЬЮ && !СЕАНС) {
  throw new Error('предпросмотр темы работает только у сотрудника — нужен TT_SESSION_FILE');
}
if (ПРЕВЬЮ) {
  /*
    ⚠️ Оговорка, без которой прогон легко прочитать неверно. Предпросмотр темы
    Discourse даёт ТОЛЬКО сотруднику — значит все проверки здесь идут от лица
    сотрудника, а часть из них про то, что видит ГОСТЬ. Ядро, например, прячет
    от гостя профиль новичка (`hide_new_user_profiles`), и сотруднику он
    откроется: проверка пройдёт там, где гость увидел бы пустоту.

    Отсюда разделение труда, и держать его в голове обязательно:
      предвыкатный прогон  — «тема не разваливается», разметка собирается;
      боевой прогон без сеанса — «что видит посетитель».
    Второй не отменяется первым.
  */
  console.log(`\nРежим: ПРЕДВЫКАТНЫЙ — тема #${ПРЕВЬЮ} (ветка staging), сеанс сотрудника.`);
  console.log('⚠️ Гостевые свойства этим прогоном НЕ проверяются — только боевым.\n');
}

const проверка = (имя, ок, подробности = '') => {
  итоги.push({ имя, ок, подробности });
  console.log(`  ${ок ? '✓' : '✗'} ${имя}${подробности ? ` — ${подробности}` : ''}`);
};

/*
  ⚠️ «Неприменимо» — не то же, что «провалено». Провал означает поломку темы;
  неприменимость — что на форуме нет данных, на которых проверку можно провести
  (например, ни одной темы с принятым ответом). Свалить их в одну кучу значит
  однажды перестать читать отчёт, потому что «там всегда что-то красное».
*/
const пропуск = (имя, причина) => {
  итоги.push({ имя, пропущено: true, подробности: причина });
  console.log(`  ⏸ ${имя} — ${причина}`);
};

const открыть = async (browser, путь, опции = {}) => {
  const ctx = await browser.newContext({
    viewport: опции.viewport || { width: 1440, height: 1000 },
    locale: опции.locale || 'ru-RU',
    colorScheme: опции.colorScheme || 'light',
    ...(опции.userAgent ? { userAgent: опции.userAgent } : {}),
  });
  const хост = new URL(БАЗА).hostname;
  const куки = [];
  if (опции.locale) {
    куки.push({ name: 'locale', value: опции.locale.split('-')[0], domain: хост, path: '/' });
  }
  /*
    ⚠️ Сеанс НЕ ставится гостевым проверкам. Их смысл в том, что видит
    неавторизованный посетитель; подложив им куку сотрудника, мы бы проверяли
    совсем другое и не заметили бы этого — страница ведь отрисуется.
  */
  if (СЕАНС && !опции.гость) {
    куки.push({ name: '_t', value: СЕАНС, domain: хост, path: '/', httpOnly: true, secure: true });
  }
  if (куки.length) await ctx.addCookies(куки);

  const page = await ctx.newPage();
  const ошибки = [];
  page.on('pageerror', (e) => ошибки.push(String(e).slice(0, 140)));

  // Предпросмотр темы — параметром адреса, как это делает сам Discourse.
  let адрес = БАЗА + путь;
  if (ПРЕВЬЮ && !опции.гость) {
    адрес += (адрес.includes('?') ? '&' : '?') + 'preview_theme_id=' + ПРЕВЬЮ;
  }
  await page.goto(адрес, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('#main-outlet', { timeout: 30000 });
  await page.waitForTimeout(опции.wait ?? 6000);
  return { ctx, page, ошибки };
};

/*
  Ожидание условия на странице — опросом через `page.evaluate`, а НЕ
  `page.waitForFunction`.

  ⚠️ `waitForFunction` компилирует условие из строки, а CSP страниц форума у
  вошедшего не разрешает 'unsafe-eval': вызов падает мгновенно с EvalError.
  Обёрнутый в `.catch`, он выглядит как «не дождались» — а на деле не ждал ни
  миллисекунды. 17.09 так покраснела проверка 11 («предпросмотра нет»), хотя
  журнал монтирований показал живой круг через 50 мс; проверка 9–10 с тем же
  приёмом зеленела лишь потому, что круг успевал ожить к следующей строке.
  Контроль «на главной гостем работает» гипотезу не опроверг: там CSP другая.
  `page.evaluate` идёт через протокол отладки и CSP не подчиняется.
*/
const дождаться = async (page, условие, мс = 30000) => {
  const до = Date.now() + мс;
  while (Date.now() < до) {
    if (await page.evaluate(условие).catch(() => false)) return true;
    await page.waitForTimeout(250);
  }
  return false;
};

const browser = await chromium.launch();

// ── 1. Главная в светлой и тёмной ───────────────────────────────────────────
console.log('\n1 · главная в светлой и тёмной');
{
  const схемы = {};
  for (const схема of ['light', 'dark']) {
    const { ctx, page, ошибки } = await открыть(browser, '/', { colorScheme: схема });
    схемы[схема] = await page.evaluate(() => {
      const cs = getComputedStyle(document.documentElement);
      const виден = (s) => {
        const el = document.querySelector(s);
        if (!el) return false;
        const b = el.getBoundingClientRect();
        return b.width > 0 && b.height > 0;
      };
      return {
        полоса: виден('.tt-bar'),
        обложка: виден('.welcome-banner'),
        поиск: виден('.welcome-banner input'),
        карточек: document.querySelectorAll('.tt-card').length,
        призыв: виден('.tt-cta'),
        подвал: виден('.tt-foot'),
        tertiary: cs.getPropertyValue('--tertiary').trim(),
        фонСтраницы: cs.getPropertyValue('--secondary').trim(),
        фонКарточки: (() => {
          const el = document.querySelector('.tt-card');
          return el ? getComputedStyle(el).backgroundColor : null;
        })(),
        сырыеКлючи: (document.body.innerText.match(/\[[a-z_]+\.theme_translations[^\]]*\]/g) || []).length,
      };
    });
    схемы[схема].ошибки = ошибки.length;
    await ctx.close();
  }
  const s = схемы.light;
  const d = схемы.dark;
  проверка('оформление на месте в обеих схемах',
    s.полоса && s.обложка && s.поиск && s.призыв && s.подвал && d.полоса && d.обложка && d.поиск,
    `карточек ${s.карточек}/${d.карточек}`);
  // КОНТРОЛЬ: схемы обязаны РАЗЛИЧАТЬСЯ. Если совпали — применилась одна.
  проверка('схемы различаются (контроль)', s.tertiary !== d.tertiary,
    `светлая ${s.tertiary}, тёмная ${d.tertiary}`);
  проверка('карточка приподнята над страницей',
    s.фонКарточки !== null && s.фонКарточки !== s.фонСтраницы,
    `страница ${s.фонСтраницы}, карточка ${s.фонКарточки}`);
  проверка('сырых ключей перевода нет', s.сырыеКлючи === 0 && d.сырыеКлючи === 0);
  проверка('ошибок в консоли нет', s.ошибки === 0 && d.ошибки === 0);
}

// ── 2. Главная с арабским: зеркальная раскладка ─────────────────────────────
console.log('\n2 · арабская раскладка');
if (ПРЕВЬЮ) {
  /*
    ⚠️ Проверка неприменима в предвыкатном прогоне, и это НЕ поблажка.
    Язык страницы у вошедшего берётся из его профиля и перебивает куку `locale`,
    которой мы притворяемся арабом. То есть проверка мерила бы не раскладку, а
    язык учётки — и честно краснела бы на исправной теме.

    Замерено 16.09: предвыкатный прогон давал `dir=ltr` и «зеркалится 0 из 4»,
    боевой на том же коде — 20 из 20.

    Заслон, который краснеет на исправном коде, бросают на второй день. Поэтому
    здесь «неприменимо», а раскладку по-прежнему сторожит боевой прогон.
  */
  пропуск('арабская раскладка объявлена', 'у вошедшего язык из профиля перебивает куку — сторожит боевой прогон');
  пропуск('элементы зеркалятся', 'то же основание');
} else {
  const снять = async (locale) => {
    const { ctx, page } = await открыть(browser, '/', { locale });
    const r = await page.evaluate(() => {
      const W = innerWidth;
      const доля = (s) => {
        const el = document.querySelector(s);
        if (!el) return null;
        const b = el.getBoundingClientRect();
        return b.width === 0 ? null : Math.round(((b.left + b.width / 2) / W) * 100);
      };
      return {
        // ⚠️ Discourse НЕ ставит атрибут dir — направление приходит стилем.
        // Первая редакция читала атрибут, получала null и объявляла отказ при
        // том, что зеркальность тут же проходила 4 из 4.
        dir: getComputedStyle(document.documentElement).direction,
        знак: доля('.tt-bar__brand'),
        названиеКлуба: доля('.tt-club-name'),
        заголовокОбложки: доля('.tt-cover__title'),
        поиск: доля('.welcome-banner input'),
      };
    });
    await ctx.close();
    return r;
  };
  const ru = await снять('ru');
  const ar = await снять('ar');
  проверка('арабская раскладка объявлена', ar.dir === 'rtl', `dir=${ar.dir}`);
  const поля = ['знак', 'названиеКлуба', 'заголовокОбложки', 'поиск'];
  const зеркалится = поля.filter((k) => ru[k] != null && ar[k] != null && Math.abs(ar[k] - (100 - ru[k])) <= 8);
  проверка('элементы зеркалятся', зеркалится.length === поля.length,
    `${зеркалится.length} из ${поля.length}`);
  // КОНТРОЛЬ: в ru раскладка обязана быть ltr, иначе сравнивать было бы не с чем
  проверка('русская раскладка не rtl (контроль)', ru.dir !== 'rtl', `dir=${ru.dir}`);
}

// ── 3. Названия разделов на de и ja: карточка не ломается ───────────────────
console.log('\n3 · карточка на длинном и коротком названии');
{
  const мерить = async (locale) => {
    const { ctx, page } = await открыть(browser, '/', { locale });
    const r = await page.evaluate(() =>
      [...document.querySelectorAll('.tt-card')].map((c) => {
        const имя = c.querySelector('.tt-card__name');
        const b = c.getBoundingClientRect();
        return {
          текст: имя ? имя.textContent.trim() : '',
          высота: Math.round(b.height),
          // выезжает ли содержимое за карточку
          перелив: c.scrollWidth > c.clientWidth + 1 || c.scrollHeight > c.clientHeight + 1,
        };
      }),
    );
    await ctx.close();
    return r;
  };
  for (const loc of ['de', 'ja']) {
    const карточки = await мерить(loc);
    const переливы = карточки.filter((k) => k.перелив).length;
    const длины = карточки.map((k) => k.текст.length);
    проверка(`${loc}: карточки без перелива`, переливы === 0 && карточки.length === 6,
      `карточек ${карточки.length}, длина имени ${Math.min(...длины)}–${Math.max(...длины)} знаков`);
  }
}

// ── 4. Прокрутка темы: полоса уехала, шапка несёт заголовок ─────────────────
console.log('\n4 · прокрутка темы');
{
  const { ctx, page } = await открыть(browser, '/latest');
  const ссылка = await page.$eval('.topic-list-item a.title', (a) => a.getAttribute('href')).catch(() => null);
  await ctx.close();
  if (!ссылка) {
    проверка('нашлась тема для проверки', false, 'в ленте нет тем');
  } else {
    const { ctx: c2, page: p2 } = await открыть(browser, ссылка);
    /*
      ⚠️ Сначала В НАЧАЛО страницы, и только потом мерим «до».

      Вошедшего движок возвращает к последнему прочитанному сообщению — страница
      открывается уже прокрученной, полоса продукта оказывается выше окна, и
      замер «до» давал false при исправной теме. Поймано 16.09 первым же
      предвыкатным прогоном: «до false, после false» на коде, который в боевом
      прогоне проходил.

      Гостю это ничего не меняет: он и так в начале. Значит правка делает
      проверку вернее в обоих режимах, а не подгоняет её под один.
    */
    await p2.evaluate(() => window.scrollTo(0, 0));
    await p2.waitForTimeout(600);
    const до = await p2.evaluate(() => {
      const bar = document.querySelector('.tt-bar');
      return { полосаВидна: bar ? bar.getBoundingClientRect().bottom > 0 : null };
    });
    await p2.evaluate(() => window.scrollTo(0, 1200));
    await p2.waitForTimeout(1500);
    const после = await p2.evaluate(() => {
      const bar = document.querySelector('.tt-bar');
      const инфо = document.querySelector('.d-header .topic-link, .extra-info-wrapper .topic-link');
      return {
        полосаВидна: bar ? bar.getBoundingClientRect().bottom > 0 : null,
        заголовокВШапке: infoТекст(инфо),
      };
      function infoТекст(el) {
        if (!el) return null;
        const b = el.getBoundingClientRect();
        return b.width > 0 ? el.textContent.trim().slice(0, 40) : null;
      }
    });
    await c2.close();
    проверка('полоса продукта уехала при прокрутке', до.полосаВидна === true && после.полосаВидна === false,
      `до ${до.полосаВидна}, после ${после.полосаВидна}`);
    проверка('шапка несёт заголовок темы', !!после.заголовокВШапке, после.заголовокВШапке || 'нет');
  }
}

// ── 5. Пустой раздел: приглашение, а не «0 тем» ─────────────────────────────
console.log('\n5 · пустой раздел');
{
  const { ctx, page } = await открыть(browser, '/');
  const r = await page.evaluate(() => {
    const пустые = [...document.querySelectorAll('.tt-card')].filter((c) => c.querySelector('.tt-card__invite'));
    const счётчики = [...document.querySelectorAll('.tt-card__count')].map((e) => e.textContent.trim());
    return {
      сПриглашением: пустые.length,
      приглашение: пустые[0]?.querySelector('.tt-card__invite')?.textContent.trim() || null,
      счётчики,
      естьНоль: счётчики.some((t) => /(^|\D)0(\D|$)/.test(t)),
    };
  });
  await ctx.close();
  проверка('у пустых разделов приглашение', r.сПриглашением > 0, r.приглашение || '—');
  проверка('нигде не написано «0 тем»', !r.естьНоль, `счётчики: ${r.счётчики.join(' · ') || 'нет'}`);
}

// ── 6. Профиль: ни одного нуля на экране ────────────────────────────────────
console.log('\n6 · профиль');
{
  // ⚠️ Имя берём из ВЫДАЧИ справочника, а не селектором таблицы: разметка
  // списка участников — классы ядра, они меняются без предупреждения, и первая
  // редакция объявила «список пуст» при шести живых участниках.
  const ctx = await browser.newContext();
  const ответ = await ctx.request.get(БАЗА + '/directory_items.json?period=all&order=likes_received', { failOnStatusCode: false });
  const тело = ответ.status() === 200 ? await ответ.json().catch(() => null) : null;
  /*
    ⚠️ Берём участника С СООБЩЕНИЯМИ. Ядро прячет от гостя профиль новичка:
    `hide_new_user_profiles` (умолчание — включено) закрывает всех, у кого
    post_count = 0 и уровень доверия ниже второго. Первая редакция брала первого
    подряд, получала 404 и объявляла отказ темы — при том, что это штатное
    поведение движка.
  */
  const все = тело?.directory_items || [];
  const сСообщениями = все.find((i) => (i.post_count || 0) > 0 || (i.user?.post_count || 0) > 0);
  const имя = сСообщениями?.user?.username || null;
  const всегоУчастников = все.length;
  await ctx.close();
  if (!имя) {
    пропуск('профиль участника', `из ${всегоУчастников} участников ни у кого нет сообщений — гостю профили новичков закрыты ядром`);
  } else {
    const { ctx: c2, page: p2 } = await открыть(browser, `/u/${имя}/summary`);
    const r = await p2.evaluate(() => {
      const текст = document.querySelector('#main-outlet')?.innerText || '';
      const нули = (текст.match(/(^|\s)0(\s|$)/g) || []).length;
      return { нули, естьСводка: !!document.querySelector('.user-content, .user-summary, .top-section') };
    });
    await c2.close();
    проверка('сводка профиля отрисовалась (контроль)', r.естьСводка);
    проверка('нулей на экране нет', r.нули === 0, `найдено ${r.нули}`);
  }
}

// ── 7. Вопрос с решением ────────────────────────────────────────────────────
console.log('\n7 · вопрос с решением');
{
  const { ctx, page } = await открыть(browser, '/latest');
  const r = await page.evaluate(() => {
    const строки = [...document.querySelectorAll('.topic-list-item')];
    const сГалочкой = строки.filter((tr) => tr.querySelector('.d-icon-check, .solved, [class*="solved"]'));
    return { тем: строки.length, решённых: сГалочкой.length };
  });
  // Сколько решённых ЕСТЬ на форуме вообще — спрашиваем поиск, а не разметку
  const поиск = await ctx.request.get(БАЗА + '/search.json?q=status%3Asolved', { failOnStatusCode: false });
  const дано = поиск.status() === 200 ? await поиск.json().catch(() => null) : null;
  r.всегоРешённыхНаФоруме = (дано?.topics || []).length;
  await ctx.close();
  проверка('список тем отрисовался (контроль)', r.тем > 0, `тем ${r.тем}`);
  /*
    ⚠️ На 15.09 на форуме НЕТ ни одной темы с принятым ответом, хотя решения
    включены в разделах «Вопросы» и «Теория и гармония». Это не поломка темы —
    это отсутствие содержания, на котором проверку можно провести.
  */
  if (r.всегоРешённыхНаФоруме === 0) {
    пропуск('решённые помечены в списке', 'на форуме нет ни одной темы с принятым ответом');
  } else {
    проверка('решённые помечены в списке', r.решённых > 0, `помечено ${r.решённых}`);
  }
}

// ── 8. Googlebot остаётся закрытым ──────────────────────────────────────────
console.log('\n8 · закрытость от поиска');
{
  const ctx = await browser.newContext({
    userAgent: 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
  });
  const r = await ctx.request.get(БАЗА + '/', { failOnStatusCode: false });
  // КОНТРОЛЬ: обычный браузер обязан получить 200, иначе 403 ничего не доказывает
  const ctx2 = await browser.newContext();
  const r2 = await ctx2.request.get(БАЗА + '/', { failOnStatusCode: false });
  await ctx.close();
  await ctx2.close();
  проверка('обычный посетитель проходит (контроль)', r2.status() === 200, `HTTP ${r2.status()}`);
  проверка('googlebot получает 403', r.status() === 403, `HTTP ${r.status()}`);
}

// ── 9–10. Виджет в посте и в письме — волна F ───────────────────────────────
/*
  Круг ладов живёт в статьях, и проверять его можно только там, где он стоит:
  адрес темы — переменной TT_CIRCLE_TOPIC (например /t/topic/23).

  Неприменимость здесь бывает трёх видов, и все честные: темы с кругом нет;
  бандла /embed/circle.js на сайте ещё нет (тема выкатывается раньше сайта);
  тема — черновик, а прогон гостевой. Во всех трёх проверять нечего, и зелёным
  это не считается.
*/
console.log('\n9–10 · виджет в посте и в письме');
{
  const ТЕМА = process.env.TT_CIRCLE_TOPIC || null;
  const САЙТ = process.env.TT_SITE || 'https://terrytrilla.com';
  const бандл = await fetch(`${САЙТ}/embed/circle.js`, { method: 'HEAD' }).then((r) => r.status).catch(() => 0);

  if (!ТЕМА) {
    пропуск('круг в посте', 'не задан TT_CIRCLE_TOPIC — темы с кругом для проверки нет');
  } else if (бандл !== 200) {
    пропуск('круг в посте', `бандла ${САЙТ}/embed/circle.js нет (HTTP ${бандл}) — сайт ещё не выкатан`);
  } else {
    const { ctx, page, ошибки } = await открыть(browser, ТЕМА, { wait: 1500 });
    await page.evaluate(() => {
      window.__csp = [];
      document.addEventListener('securitypolicyviolation', (e) => window.__csp.push(`${e.violatedDirective} ${e.blockedURI}`));
    });
    const блоков = await page.locator("[data-wrap='tt-circle']").count();
    if (блоков === 0) {
      пропуск('круг в посте', `в ${ТЕМА} нет блока [wrap=tt-circle] (или тема не видна этому прогону)`);
    } else {
      const блок = page.locator("[data-wrap='tt-circle']").first();
      await блок.scrollIntoViewIfNeeded();
      await дождаться(page, () => {
        const n = document.querySelector("[data-wrap='tt-circle']");
        return !!n && ['live', 'error'].includes(n.dataset.ttCircle);
      }, 30000);
      const состояние = await блок.getAttribute('data-tt-circle');
      const нот = await блок.locator('.scale-circle-note-label').count();
      проверка('круг в посте ожил', состояние === 'live' && нот === 12, `состояние ${состояние}, меток нот ${нот}`);

      // КОНТРОЛЬ детектора: нажатие обязано изменить круг, иначе «12 меток»
      // проверяло бы картинку, а не живой виджет.
      if (состояние === 'live') {
        const до = await блок.locator('.scale-circle-note-label').evaluateAll((g) => g.map((x) => x.getAttribute('class')).join());
        await блок.locator('.scale-circle-note-label').nth(1).locator('circle').first().click({ force: true });
        await page.waitForTimeout(600);
        const после = await блок.locator('.scale-circle-note-label').evaluateAll((g) => g.map((x) => x.getAttribute('class')).join());
        проверка('нажатие на ноту меняет круг', до !== после);
        // ⚠️ Любые картинки блока, а не `:scope > p img`: ядро оборачивает
        // картинку в свой контейнер (lightbox), и прежний селектор не находил её
        // вовсе — проверка зеленела, ничего не проверяя.
        const картинок = await блок.locator('img').evaluateAll((els) => els.filter((e) => e.offsetParent !== null).length);
        проверка('запасная картинка спрятана у живого круга', картинок === 0, `видимых картинок ${картинок}`);
      }
      const csp = await page.evaluate(() => window.__csp);
      проверка('нарушений CSP нет', csp.length === 0, csp.slice(0, 3).join('; '));
      проверка('ошибок скрипта нет', ошибки.length === 0, ошибки.slice(0, 2).join('; '));

      /*
        Письмо. Живого круга в нём не бывает; туда уходит картинка из блока (F5).
        Форум скачивает её к себе (download_remote_images_to_local) и подменяет
        адрес при обработке поста — в письме должна стоять копия с форума, а не
        адрес сайта, который дёргался бы на каждое открытие письма.
      */
      const адреса = await блок.locator('img').evaluateAll((els) => els.map((e) => e.getAttribute('src') || ''));
      if (адреса.length === 0) {
        пропуск('картинка в письме', 'в блоке круга нет картинки-запаски');
      } else {
        const локальных = адреса.filter((a) => a.includes('/uploads/')).length;
        проверка('картинка-запаска — копия на форуме (уйдёт в письмо)', локальных === адреса.length, `локальных ${локальных} из ${адреса.length}`);
      }
    }
    await ctx.close();
  }
}

// ── 11. Кнопка «Виджеты TerryTrilla» в редакторе — волна F, F4 ──────────────
/*
  Автор нажимает кнопку, выбирает лад и тонику из списков, и в текст встаёт
  готовый блок с картинкой-запаской. Здесь — короткая проверка того, что
  цепочка жива на настоящем сайте: кнопка есть, справочник пришёл, вставка
  дала блок. Правку одинаковых блоков в обоих режимах редактора разбирает
  подробный пробник и spec/markup.test.mjs; сюда она не тянется, чтобы
  приёмка оставалась быстрой.

  Неприменимо: прогон гостевой (кнопка только у авторов), справочника на
  сайте ещё нет (тема выкатывается раньше сайта), не задана тема для ответа.
  ⚠️ Текст в редакторе стирается в конце — черновик ответа не остаётся.
*/
console.log('\n11 · кнопка виджетов в редакторе');
{
  const ТЕМА = process.env.TT_CIRCLE_TOPIC || null;
  const САЙТ = process.env.TT_SITE || 'https://terrytrilla.com';
  const справочник = await fetch(`${САЙТ}/api/embed/catalog?widget=circle&locale=ru`, {
    headers: { origin: БАЗА },
  }).then((r) => r.status).catch(() => 0);

  if (!СЕАНС) {
    пропуск('кнопка виджетов', 'гостевой прогон — кнопка только у авторов базы знаний');
  } else if (!ТЕМА) {
    пропуск('кнопка виджетов', 'не задан TT_CIRCLE_TOPIC — негде открыть редактор');
  } else if (справочник !== 200) {
    пропуск('кнопка виджетов', `справочника ${САЙТ}/api/embed/catalog нет (HTTP ${справочник}) — сайт ещё не выкатан`);
  } else {
    const { ctx, page, ошибки } = await открыть(browser, ТЕМА, { wait: 3000 });
    const поле = page.locator('textarea.d-editor-input');
    try {
      await page.locator('.topic-footer-main-buttons button.create, button.reply-to-post').first().click();
      await page.locator('.d-editor').waitFor({ timeout: 20000 });
      if ((await page.locator('.d-editor .ProseMirror').count()) > 0) {
        await page.locator('.composer-toggle-switch').first().click();
        await поле.waitFor({ timeout: 10000 });
      }
      await поле.fill('');
      проверка('контроль: в пустом ответе блока нет', !(await поле.inputValue()).includes('[wrap=tt-circle'));

      const кнопка = page.locator('.d-editor-button-bar button.tt-widgets');
      проверка('кнопка «Виджеты TerryTrilla» на панели', (await кнопка.count()) === 1);
      await кнопка.click();
      const лад = page.locator('.tt-widget-modal select[data-field="scale"]');
      await лад.waitFor({ timeout: 20000 });
      const ладов = await лад.locator('option').count();
      проверка('справочник сайта пришёл: лады в списке', ладов > 50, `ладов ${ладов}`);

      await лад.selectOption('dorian');
      await page.locator('.tt-widget-modal .tt-wm__root[data-root="D"]').click();
      const сцена = await дождаться(page, () => !!document.querySelector('.tt-wm__stage svg'), 30000);
      проверка('живой предпросмотр в окне', сцена);

      await page.locator('.tt-widget-modal .tt-wm__apply').click();
      await page.locator('.tt-widget-modal').waitFor({ state: 'detached', timeout: 10000 });
      const текст = await поле.inputValue();
      проверка(
        'вставлен блок с картинкой-запаской',
        /\[wrap=tt-circle[^\]\n]* scale=dorian root=D\]\n!\[[^\]]+\]\([^)]*\/api\/embed\/circle-image\?[^)]*scale=dorian&root=D[^)]*\)\n\[\/wrap\]/.test(текст),
        текст.slice(0, 160)
      );
      проверка('ошибок скрипта нет', ошибки.length === 0, ошибки.slice(0, 2).join('; '));
    } catch (e) {
      проверка('кнопка виджетов', false, String(e).slice(0, 160));
    } finally {
      await поле.fill('').catch(() => {});
      await ctx.close();
    }
  }
}

// ── 12. Имя «Community» (C4 ТЗ-FORUM-LAUNCH, Р-11) ─────────────────────────
console.log('\n12 · открытый форум называется сообществом, а не клубом');
{
  /*
    «Клуб» по решению Р-11 — только закрытая платная часть. Открытый форум в шапке,
    подвале, обложке и описаниях разделов называется сообществом, словом из словарей
    сайта (`community` в apps/web/src/i18n/locales). Проверяется то, что ВИДИТ
    посетитель, а не ключи в yml: строку разделов, например, пишет не тема, а
    CategoryLocalization на форуме.

    ⚠️ Длина. «Клуб» был в 4 знака, «Сообщество» и «Społeczność» — в 11. Название
    стоит в одной строке шапки с навигацией разделов и не переносится (`nowrap`),
    поэтому опасность не перенос, а НАЕЗД на навигацию — он и мерится: пересечение
    прямоугольников названия и `.tt-club-nav`.

    ⚠️ Первая редакция 17.09 мерила перенос названия и перелив шапки — и была
    зелёной по построению: у названия `nowrap`, а на телефоне оно скрыто стилем
    (`display: none` до 767 px, так с 15.09). Сторож, который не может покраснеть,
    хуже отсутствия сторожа. Теперь у геометрии есть КОНТРОЛЬ: в название
    подставляется заведомо длинная строка, и детектор обязан увидеть поломку шапки.

    В предвыкатном прогоне язык страницы — из профиля сотрудника (как в проверке 2),
    поэтому там один язык; все двенадцать гостем проверяет боевой прогон.
  */
  const ИМЯ = {
    en: 'Community', ru: 'Сообщество', uk: 'Спільнота', de: 'Community', fr: 'Communauté',
    es: 'Comunidad', pt: 'Comunidade', it: 'Community', pl: 'Społeczność', ar: 'المجتمع',
    ja: 'コミュニティ', ko: '커뮤니티',
  };
  const КЛУБ = /(^|[^a-z])(club|clube|klub)([^a-z]|$)|клуб|クラブ|클럽|النادي/i;
  const снять = async (locale, viewport, подставить = null) => {
    const { ctx, page, ошибки } = await открыть(browser, '/', { locale, viewport });
    const r = await page.evaluate((подставить) => {
      const текст = (s) => [...document.querySelectorAll(s)].map((e) => e.innerText || '').join(' ');
      const имя = document.querySelector('.tt-club-name');
      if (имя && подставить) имя.textContent = подставить;
      const nav = document.querySelector('.tt-club-nav');
      const виден = (el) => !!el && getComputedStyle(el).display !== 'none' && el.getBoundingClientRect().width > 0;
      let наезд = null;
      if (виден(имя) && виден(nav)) {
        const a = имя.getBoundingClientRect();
        const b = nav.getBoundingClientRect();
        const поГоризонтали = Math.min(a.right, b.right) - Math.max(a.left, b.left);
        const поВертикали = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);
        наезд = поГоризонтали > 1 && поВертикали > 1;
      }
      return {
        lang: document.documentElement.lang,
        имя: имя ? имя.textContent.trim() : null,
        имяВидно: виден(имя),
        навигацияВидна: виден(nav),
        наезд,
        заКраем: виден(имя) ? имя.getBoundingClientRect().right > innerWidth + 1 || имя.getBoundingClientRect().left < -1 : false,
        видимое: [текст('.d-header'), текст('.tt-foot, .tt-footer'), текст('.tt-cover'), текст('.tt-card')]
          .join(' ')
          .replace(/terrytrilla\.club/gi, ''),
      };
    }, подставить);
    await ctx.close();
    return { ...r, ошибки: ошибки.length };
  };

  // КОНТРОЛЬ детектора слов: он обязан узнавать прежние строки, иначе «клуба нет» ничего не доказывает
  проверка('детектор узнаёт «Правила клуба», «Club rules», «Klub» (контроль)',
    ['Правила клуба', 'Club rules', 'Klub', 'クラブの規約'].every((s) => КЛУБ.test(s)) && !КЛУБ.test('TerryTrilla Community · Сообщество'));

  // КОНТРОЛЬ геометрии: заведомо длинное название обязано наехать на навигацию
  {
    const длинное = 'Społeczność '.repeat(12).trim();
    const r = await снять(ПРЕВЬЮ ? null : 'pl-PL', undefined, длинное);
    // ⚠️ Замер 17.09: длинное название не наезжает, а ВЫТАЛКИВАЕТ навигацию — она
    // пропадает совсем. Поэтому исчезновение навигации — тоже дефект, и основная
    // проверка требует «навигация видна».
    проверка('детектор видит, что длинное название ломает шапку (контроль)',
      r.навигацияВидна === false || r.наезд === true || r.заКраем === true,
      `навигация видна ${r.навигацияВидна}, наезд ${r.наезд}, за краем ${r.заКраем}`);
  }

  const языки = ПРЕВЬЮ ? [null] : Object.keys(ИМЯ);
  for (const loc of языки) {
    const r = await снять(loc === 'pt' ? 'pt-BR' : loc === 'pl' ? 'pl-PL' : loc, undefined);
    const код = (r.lang || '').split(/[-_]/)[0];
    const ждём = ИМЯ[код];
    const метка = loc ?? `${код} (профиль)`;
    проверка(`${метка}: в шапке «${ждём}»`, !!ждём && r.имя === ждём, `lang=${r.lang}, в шапке «${r.имя}»`);
    const найдено = r.видимое.match(КЛУБ);
    проверка(`${метка}: «клуба» нет в шапке, подвале, обложке, разделах`, !найдено, найдено ? `…${r.видимое.slice(Math.max(0, найдено.index - 30), найдено.index + 30)}…` : '');
    проверка(`${метка}: название не наезжает на навигацию`, r.имяВидно && r.навигацияВидна && r.наезд === false && !r.заКраем,
      `название видно ${r.имяВидно}, навигация видна ${r.навигацияВидна}, наезд ${r.наезд}, за краем ${r.заКраем}`);
  }
  // Телефон: название скрыто стилем по макету — проверяем, что это так, а не меряем пустоту
  {
    const r = await снять(ПРЕВЬЮ ? null : 'pl-PL', { width: 390, height: 844 });
    if (r.имяВидно) {
      проверка('телефон: название не уходит за край', !r.заКраем, `за краем ${r.заКраем}`);
    } else {
      пропуск('телефон: название не уходит за край', 'на телефоне название скрыто стилем (до 767 px, макет 15.09)');
    }
  }
}

// ── 13. Прямых ссылок на цены нет (C1 ТЗ-FORUM-LAUNCH, Р-13) ────────────────
console.log('\n13 · прямых ссылок на цены и оплату нет');
{
  /*
    Apple 3.1.3 и правила Google Play: из приложения через форум нельзя вести к
    покупке. Нейтральные ссылки на сайт (справочник, блог, условия) допустимы,
    прямые на цены и оплату — нет. До 17.09 в подвале темы стоял пункт «Тарифы».

    ⚠️ Проверяется БРАУЗЕРОМ: ссылки подвала рисует JS темы, и curl по HTML их не
    видит — дал бы ложный зелёный. Второй слой — текст собранного JS темы: ссылка
    может жить в коде и появляться только в другом состоянии страницы.
  */
  const ЦЕНЫ = /\/(pricing|checkout|subscribe|plans)(\b|\/|\?|$)/i;
  проверка('детектор узнаёт /pricing, /checkout?x, но не /scales (контроль)',
    ЦЕНЫ.test('https://terrytrilla.com/pricing') && ЦЕНЫ.test('/checkout?plan=1') && !ЦЕНЫ.test('https://terrytrilla.com/scales'));

  for (const путь of ['/', '/t/topic/15']) {
    const { ctx, page } = await открыть(browser, путь, { гость: !ПРЕВЬЮ });
    const r = await page.evaluate(() => ({
      ссылок: document.querySelectorAll('a[href]').length,
      адреса: [...document.querySelectorAll('a[href]')].map((a) => a.href),
      // ⚠️ Не только <script src>: JS темы лежит в нескольких файлах, часть грузится
      // модулем. Первая редакция 17.09 брала теги, видела 1 файл из 2 и была зелёной
      // при живом "/pricing" в коде. Журнал загрузок браузера видит все.
      скрипты: [...new Set([
        ...[...document.querySelectorAll('script[src], link[href]')].map((e) => e.src || e.href),
        ...performance.getEntriesByType('resource').map((e) => e.name),
      ])].filter((u) => u.includes('/theme-javascripts/')),
      подвал: !!document.querySelector('.tt-foot'),
    }));
    const найдено = r.адреса.filter((h) => ЦЕНЫ.test(h));
    проверка(`${путь}: подвал отрисовался, ссылки собраны (контроль)`, r.подвал && r.ссылок > 20, `ссылок ${r.ссылок}`);
    проверка(`${путь}: ссылок на цены нет`, найдено.length === 0, найдено.slice(0, 3).join(' '));
    if (путь === '/') {
      let вКоде = [];
      for (const src of r.скрипты) {
        const текст = await page.evaluate((u) => fetch(u).then((x) => x.text()), src).catch(() => '');
        const m = текст.match(/["'`][^"'`\n]*\/(pricing|checkout|subscribe|plans)\b[^"'`\n]*["'`]/gi) || [];
        вКоде = вКоде.concat(m);
      }
      проверка('JS темы загружен — не меньше двух файлов (контроль)', r.скрипты.length >= 2, `файлов ${r.скрипты.length}`);
      проверка('в JS темы адресов цен нет', вКоде.length === 0, вКоде.slice(0, 3).join(' '));
    }
    await ctx.close();
  }
}

// ── 14. «Поделиться» несёт язык читателя (C2 ТЗ-FORUM-LAUNCH, Р-10) ─────────
console.log('\n14 · «Поделиться» несёт язык читателя');
{
  /*
    Ссылка, которой человек делится, обязана нести язык: на адресе без параметра
    язык берётся из браузера получателя, а бот всегда получает язык форума (B12).
    Параметр ставится только на переведённой теме и только не для языка форума.

    ⚠️ Читается ЖИВАЯ ссылка: у каждого поста ядро кладёт её в data-share-url, а
    ссылку темы показывает окно «Поделиться». Разбор кода темы ничего не доказал
    бы — геттеры ядра могут переехать, и язык молча перестанет попадать в ссылку.
  */
  // t/17 переведена на 12 языков (и написана по-русски), t/10 — служебная тема без переводов.
  const языкСсылки = (url) => (String(url).match(/[?&]tl=([^&]+)/) || [, null])[1];
  проверка("детектор узнаёт ?tl=ru и &tl=ja, но не адрес без языка (контроль)",
    языкСсылки("https://x/t/a/1?tl=ru") === "ru" && языкСсылки("https://x/t/a/1?u=b&tl=ja") === "ja" && языкСсылки("https://x/t/a/1") === null);

  for (const [путь, переведена] of [["/t/17", true], ["/t/10", false]]) {
    const { ctx, page } = await открыть(browser, путь, { гость: true, locale: "ru" });
    const r = await page.evaluate(() => ({
      постов: document.querySelectorAll("[data-share-url]").length,
      ссылки: [...document.querySelectorAll("[data-share-url]")].map((e) => e.getAttribute("data-share-url")),
      язык: document.documentElement.lang,
    }));
    проверка(`${путь}: посты и их ссылки на месте (контроль)`, r.постов > 0 && r.язык.startsWith("ru"), `постов ${r.постов}, язык ${r.язык}`);
    const языки = [...new Set(r.ссылки.map(языкСсылки))];
    if (переведена) {
      проверка(`${путь}: ссылка поста несёт tl=ru`, языки.length === 1 && языки[0] === "ru", языки.join(","));
    } else {
      проверка(`${путь}: ссылка поста без языка`, языки.every((l) => l === null), языки.join(","));
    }
    await ctx.close();
  }
}

await browser.close();

const пропущены = итоги.filter((i) => i.пропущено);
const плохих = итоги.filter((i) => !i.пропущено && !i.ок);
console.log(`\n${'─'.repeat(60)}`);
console.log(`проверок ${итоги.length}: прошли ${итоги.length - плохих.length - пропущены.length}, не прошли ${плохих.length}, неприменимы ${пропущены.length}`);
плохих.forEach((i) => console.log(`  ✗ ${i.имя} — ${i.подробности}`));
пропущены.forEach((i) => console.log(`  ⏸ ${i.имя} — ${i.подробности}`));
process.exit(плохих.length ? 1 : 0);
