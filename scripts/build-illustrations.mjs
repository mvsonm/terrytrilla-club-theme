import { readFileSync, writeFileSync, readdirSync } from 'fs';
import { fileURLToPath } from 'url';

/*
  Иллюстрации разделов: из `assets/illustrations/*.svg` в модуль разметки.

  ⚠️ ПОЧЕМУ В РАЗМЕТКУ, А НЕ ФАЙЛАМИ. Картинки красятся переменными CSS
  (`--ill-cat`, `--ill-cat-hi`, `--ill-tint`, `--ill-cat-soft`), а переменные
  страницы НЕ ДОХОДЯТ до SVG, подключённого как `background-image` или `<img>`:
  такой SVG рисуется в отдельном окружении и возьмёт запасные значения, зашитые
  в самом файле. А они светлые — в ночной схеме вышли бы белые пятна.

  Это тот же класс, что с чужими шрифтами внутри фоновой картинки (§20
  методики): внутрь картинки-как-изображения ничего снаружи не попадает.

  Запуск из корня темы:  node scripts/build-illustrations.mjs
*/

const КОРЕНЬ = fileURLToPath(new URL('../', import.meta.url));
const ИЗ = КОРЕНЬ + 'assets/illustrations/';
const В = КОРЕНЬ + 'javascripts/discourse/lib/tt-illustrations.js';

const файлы = readdirSync(ИЗ).filter((f) => f.endsWith('.svg')).sort();
const записи = [];

for (const f of файлы) {
  const слаг = f.replace('.svg', '');
  const svg = readFileSync(ИЗ + f, 'utf8').trim();

  // Проверки на входе: молчаливая порча дороже отказа сборки
  if (!svg.startsWith('<svg')) throw new Error(`${f}: не начинается с <svg`);
  if (svg.includes('<metadata>')) throw new Error(`${f}: остался манифест C2PA`);
  if (svg.includes('<text')) throw new Error(`${f}: есть <text> — на чужой машине станет квадратами`);
  for (const m of svg.matchAll(/url\(#([^)]+)\)/g)) {
    if (!svg.includes(`id="${m[1]}"`)) throw new Error(`${f}: ссылка на #${m[1]}, объявления нет`);
  }
  const ids = [...svg.matchAll(/id="([^"]+)"/g)].map((m) => m[1]);
  if (ids.some((id) => !id.startsWith('tt-ill-'))) {
    throw new Error(`${f}: идентификатор без префикса tt-ill- — на одной странице столкнётся с соседним`);
  }

  записи.push([слаг, svg]);
}

// ⚠️ Идентификаторы обязаны быть уникальны ПО ВСЕМ файлам, а не внутри каждого:
// на странице они окажутся рядом.
const всеId = записи.flatMap(([, svg]) => [...svg.matchAll(/id="([^"]+)"/g)].map((m) => m[1]));
const дубли = всеId.filter((id, i) => всеId.indexOf(id) !== i);
if (дубли.length) throw new Error(`одинаковые идентификаторы на одной странице: ${[...new Set(дубли)].join(', ')}`);

const тело = записи.map(([слаг, svg]) => `  "${слаг}": ${JSON.stringify(svg)},`).join('\n');

writeFileSync(
  В,
  `/*
  СОБРАНО СКРИПТОМ — не править руками.
  Источник: assets/illustrations/*.svg, сборка: node scripts/build-illustrations.mjs

  Разметка вставляется в страницу, а не подключается файлом: иначе переменные
  цвета темы до картинок не доходят и они останутся светлыми в ночной схеме.
*/
export const ИЛЛЮСТРАЦИИ = {
${тело}
};

export function иллюстрация(слаг) {
  return ИЛЛЮСТРАЦИИ[слаг] || null;
}
`,
  'utf8',
);

const вес = записи.reduce((s, [, svg]) => s + svg.length, 0);
console.log(`собрано ${записи.length} иллюстраций, ${(вес / 1024).toFixed(1)} КБ разметки`);
записи.forEach(([слаг, svg]) => console.log(`  ${слаг.padEnd(16)} ${String(svg.length).padStart(4)} Б`));
console.log(`\nмодуль: ${В.replace(КОРЕНЬ, '')}`);
