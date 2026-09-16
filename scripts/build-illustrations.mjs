import { readdirSync, writeFileSync, statSync, mkdirSync, rmSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

/*
  Иллюстрации разделов из растровых исходников владельца.

  ⚠️ Прежняя версия собирала SVG в разметку страницы — это было нужно, чтобы до
  картинок доходили переменные цвета темы. С РАСТРОМ это бессмысленно: пиксели
  перекрасить нечем. Поэтому здесь другой механизм — файлы объявляются ресурсами
  темы и подключаются фоном.

  Что это меняет по существу: рисунок больше не следует за схемой. Значит он
  обязан читаться и на светлой карточке, и на тёмной КАК ЕСТЬ, а проверка этого
  — замер, а не надежда.

  Исходники: docs/Discourse/DESIGN/*.png монорепо, 1254×1254, 3,0 МБ на шесть.
  Запуск из корня темы:  node scripts/build-illustrations.mjs
*/

const require = createRequire('file:///C:/WMVsonm/bot-Tuzik/');
const sharp = require('./node_modules/.pnpm/sharp@0.34.5/node_modules/sharp');

const КОРЕНЬ = fileURLToPath(new URL('../', import.meta.url));
const ИЗ = 'C:/WMVsonm/bot-Tuzik/docs/Discourse/DESIGN';
const В = КОРЕНЬ + 'assets/illustrations/';

// Имя файла у владельца → слаг раздела на форуме
const СЛАГ = {
  'Start here': 'start-here',
  Questions: 'questions',
  'Theory & Harmony': 'theory',
  'Show your work': 'show-your-work',
  'Ideas & Feedback': 'ideas',
  General: 'general',
};

/*
  На карточке рисунок показывается 112 px. Берём вдвое — 224 — ради экранов с
  двойной плотностью. Больше не нужно: третий множитель глазом не различается, а
  вес растёт вчетверо.
*/
const РАЗМЕР = 224;

// Старое SVG-хозяйство убираем целиком: два механизма на одну задачу однажды
// разойдутся, и никто не поймёт, какой из них рисует.
if (existsSync(В)) rmSync(В, { recursive: true, force: true });
mkdirSync(В, { recursive: true });
const модуль = КОРЕНЬ + 'javascripts/discourse/lib/tt-illustrations.js';
if (existsSync(модуль)) rmSync(модуль);

let былоВсего = 0;
let сталоВсего = 0;
const отчёт = [];

for (const [имя, слаг] of Object.entries(СЛАГ)) {
  const путь = `${ИЗ}/${имя}.png`;
  if (!existsSync(путь)) throw new Error(`нет исходника: ${имя}.png`);
  былоВсего += statSync(путь).size;

  const исх = sharp(путь).resize(РАЗМЕР, РАЗМЕР, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } });

  /*
    ⚠️ Формат выбираем ЗАМЕРОМ, а не по правилу «webp всегда меньше». На этих
    рисунках — мягкие переходы с прозрачностью — палитровый PNG выигрывает у
    webp на четырёх из шести, и разница доходит до двух раз.
  */
  const png = await исх.clone().png({ compressionLevel: 9, palette: true, effort: 10 }).toBuffer();
  const webp = await исх.clone().webp({ quality: 88, effort: 6 }).toBuffer();
  const [расш, буфер] = png.length <= webp.length ? ['png', png] : ['webp', webp];

  writeFileSync(`${В}${слаг}.${расш}`, буфер);
  сталоВсего += буфер.length;
  отчёт.push({ слаг, расш, вес: буфер.length, png: png.length, webp: webp.length });
}

console.log('собрано:');
for (const r of отчёт) {
  console.log(
    `  ${r.слаг.padEnd(16)} ${r.расш.padEnd(4)} ${String(Math.round(r.вес / 1024)).padStart(3)} КБ` +
      `   (png ${Math.round(r.png / 1024)} / webp ${Math.round(r.webp / 1024)})`,
  );
}
console.log(`\n  исходники ${(былоВсего / 1048576).toFixed(1)} МБ → ${(сталоВсего / 1024).toFixed(0)} КБ`);

// ── Объявление ресурсов для about.json ──────────────────────────────────────
console.log('\nстроки для "assets" в about.json:');
for (const r of отчёт) {
  console.log(`    "ill-${r.слаг}": "assets/illustrations/${r.слаг}.${r.расш}",`);
}

// ── Контроль: читаем ЗАПИСАННОЕ ─────────────────────────────────────────────
console.log('\n=== контроль ===');
const файлы = readdirSync(В);
console.log(`  файлов: ${файлы.length} (ожидаем 6)`);
let бед = 0;
for (const r of отчёт) {
  const p = `${В}${r.слаг}.${r.расш}`;
  const m = await sharp(p).metadata();
  const raw = await sharp(p).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const W = raw.info.width;
  const уголАльфа = raw.data[3];
  const ок = m.width === РАЗМЕР && m.height === РАЗМЕР && уголАльфа === 0;
  if (!ок) бед += 1;
  console.log(`  ${r.слаг.padEnd(16)} ${m.width}×${m.height} ${m.format} угол.альфа=${уголАльфа} ${ок ? '✓' : '✗'}`);
}
console.log(`  бед: ${бед}`);
