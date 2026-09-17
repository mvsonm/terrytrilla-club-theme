/*
  Разметка виджетов (F4) — обычным node, без браузера и без форума:

    node --test spec/markup.test.mjs

  Сторожит то, что глазом не видно: блок собирается в той форме, которую
  понимает декоратор (tt-circle.gjs), и правка находит ИМЕННО блок под
  курсором, а не первый похожий.
*/
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  blockAt,
  buildBlock,
  EDIT_MARK,
  findBlocks,
  markedBlockRegex,
  parseAttrs,
  valuesFromAttrs,
  widgetByWrap,
} from "../javascripts/discourse/lib/tt-widgets.js";

const circle = widgetByWrap("tt-circle");
const ctx = { base: "https://terrytrilla.com/", locale: "ru", caption: "Круг ладов: Гармонический минор, тоника A" };
const values = { preset: "cmn0vkcwd000gih7kgqe05anx", sound: "cmndlgea700007mw90owkh7cs", scale: "harmonicMinor", root: "A" };

test("блок: [/wrap] на своей строке, ключи строчные, картинка с теми же параметрами", () => {
  assert.equal(
    buildBlock(circle, values, ctx),
    [
      "[wrap=tt-circle preset=cmn0vkcwd000gih7kgqe05anx sound=cmndlgea700007mw90owkh7cs scale=harmonicMinor root=A]",
      "![Круг ладов: Гармонический минор, тоника A](https://terrytrilla.com/api/embed/circle-image?preset=cmn0vkcwd000gih7kgqe05anx&scale=harmonicMinor&root=A&locale=ru)",
      "[/wrap]",
    ].join("\n")
  );
});

test("пустые ключи не пишутся, диез в адресе экранирован, скобки из подписи убраны", () => {
  const block = buildBlock(circle, { scale: "dorian", root: "F#" }, { ...ctx, caption: "a [b] c" });
  assert.match(block, /^\[wrap=tt-circle scale=dorian root=F#\]\n/);
  assert.match(block, /root=F%23&locale=ru\)/);
  assert.match(block, /!\[a  b  c\]/);
  assert.doesNotMatch(block, /preset=|sound=/);
});

test("собранный блок разбирается обратно в те же значения", () => {
  const [block] = findBlocks(buildBlock(circle, values, ctx));
  assert.equal(block.wrap, "tt-circle");
  assert.deepEqual(valuesFromAttrs(circle, block.attrs), values);
});

test("атрибуты в кавычках и в разном регистре ключей", () => {
  assert.deepEqual(parseAttrs(`=tt-circle Scale="harmonic Minor" root='A'`), {
    wrap: "tt-circle",
    scale: "harmonic Minor",
    root: "A",
  });
});

test("курсор выбирает свой блок; вне блоков — ничего; чужие [wrap] не трогаются", () => {
  const a = buildBlock(circle, { scale: "dorian", root: "D" }, ctx);
  const b = buildBlock(circle, { scale: "dorian", root: "D" }, ctx); // точная копия первого
  const text = `Текст\n\n${a}\n\n[wrap=toc]\n[/wrap]\n\nЕщё\n\n${b}\n`;
  const blocks = findBlocks(text);
  assert.equal(blocks.length, 2, "контроль: [wrap=toc] не наш и не считается");

  const inSecond = text.lastIndexOf("scale=dorian");
  assert.equal(blockAt(text, inSecond).index, 1, "одинаковые блоки различаются по месту, а не по тексту");
  assert.equal(blockAt(text, text.indexOf("Ещё")), null);
  assert.equal(blockAt(text, text.indexOf("[wrap=toc]") + 3), null);
  assert.equal(blockAt(text, blocks[0].end).index, 0, "сразу после [/wrap] — ещё в блоке");
});

test("визуальный режим: метка находит ровно помеченный блок", () => {
  const plain = buildBlock(circle, { scale: "dorian", root: "D" }, ctx);
  const marked = plain.replace("root=D]", `root=D ${EDIT_MARK}=1]`);
  const text = `${plain}\n\n${marked}\n\n${plain}`;
  const found = [...text.matchAll(markedBlockRegex("tt-circle"))];
  assert.equal(found.length, 1);
  assert.equal(found[0].index, plain.length + 2);
  assert.equal([...plain.matchAll(markedBlockRegex("tt-circle"))].length, 0, "контроль: без метки — ничего");
  const quoted = plain.replace("root=D]", `root="D" ${EDIT_MARK}="1"]`);
  assert.equal([...quoted.matchAll(markedBlockRegex("tt-circle"))].length, 1, "метка в кавычках — так пишет сериализатор ядра");
  const lookalike = plain.replace("root=D]", `root=D ${EDIT_MARK}=10]`);
  assert.equal([...lookalike.matchAll(markedBlockRegex("tt-circle"))].length, 0);
});
