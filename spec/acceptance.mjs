/*
  ПРИЁМКА ПОВЕДЕНИЕМ (G3) — десять проверок §6 ТЗ против ЖИВОГО форума.

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
{
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
console.log('\n9–10 · виджет в посте и в письме');
console.log('  ⏸ отложено: волна F не построена, проверять нечего');

await browser.close();

const пропущены = итоги.filter((i) => i.пропущено);
const плохих = итоги.filter((i) => !i.пропущено && !i.ок);
console.log(`\n${'─'.repeat(60)}`);
console.log(`проверок ${итоги.length}: прошли ${итоги.length - плохих.length - пропущены.length}, не прошли ${плохих.length}, неприменимы ${пропущены.length}`);
плохих.forEach((i) => console.log(`  ✗ ${i.имя} — ${i.подробности}`));
пропущены.forEach((i) => console.log(`  ⏸ ${i.имя} — ${i.подробности}`));
process.exit(плохих.length ? 1 : 0);
