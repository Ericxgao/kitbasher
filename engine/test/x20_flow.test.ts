// MDX X.20 B through the page's normal steps (web/src/app.ts): the plan behind the meters, the ID
// allocation with and without a layout, the layout editor's fixed families, the layout table the build
// carries and reads back, and the build with the user's choices (with firmware only).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { idAllowedOnX20, parseRecipe, recipeFor, type X20RecipeFile } from '../src/x20_recipe.js';
import { allocateX20, buildX20, findX20Layout, planX20, trimX20Bank, X20_CATEGORIES, x20IdProblem, x20IdSlots } from '../src/x20.js';
import { buildBank, ENTRIES, E12B_FLASH } from '../src/e12b.js';
import { encodeLayout, LAYOUT_FORMAT, parseLayout, type Layout } from '../src/layout.js';
import { loadPacks } from '../src/node.js';
import { select } from '../src/selection.js';
import { encodeSyx, OS_START } from '../src/syx.js';
import { sha256 } from '../src/bytes.js';
import { osOfRecipe, osProblem } from '../src/project.js';
import { needsUwSamples } from '../src/packs.js';

const ROOT = fileURLToPath(new URL('../../../', import.meta.url));
// Keep offline implementation coverage while the shipped recipe is disabled.
const file = (): X20RecipeFile => ({ ...JSON.parse(readFileSync(join(ROOT, 'bases/x20.json'), 'utf8')), refuse: undefined });
const R = parseRecipe(file());
const { packs } = loadPacks([join(ROOT, 'catalog')]);
const models = select(packs, {}).fams.flatMap((f) => f.models.map((m) => ({ m, family: f.name })));

/** A synthetic E12B bank: 21 entries (one empty), the first `long` of them `len` samples, the rest 1000; each a loud
 *  start then silence (so the trim frees most of a long one). */
function bank(len: number, long = ENTRIES): { names: Uint8Array[]; samples: (number[] | null)[] } {
  const tail = new Array(34).fill(0);
  const samples = Array.from({ length: ENTRIES }, (_, i) => i === 3 ? null
    : [...Array.from({ length: i < long ? len : 1000 }, (_, k) => (k < 900 ? Math.round(1200 * Math.sin(k * 0.05 * (i + 1))) & 0xfff : 0)), ...tail]);
  return { names: Array.from({ length: ENTRIES }, (_, i) => Uint8Array.from(Buffer.from(`S${i}`.padEnd(4)))), samples };
}
const KEEP = { db: -30, minSeconds: Infinity, cap: null };
const TRIM = { db: -30, minSeconds: 0.5, cap: 0.55 };
// big enough that the stock-length bank leaves no room, as X.20 B's does
const BIG = bank(30000, 13);

test('x20 flow: IDs bottom-up from the recipe\'s usable list without a layout (the build as before), never 96..123 or above 191', () => {
  const a = allocateX20(R, models, true);
  assert.deepEqual(a.sel.map((s) => s.id), R.usable.slice(0, models.length));
  assert.deepEqual(a.moves, []);
  assert.ok(a.sel.every((s) => idAllowedOnX20(s.id) && s.id <= 191 && !s.mapped && s.preferred === s.m.id));
  const noUw = allocateX20(R, models, false);
  assert.ok(noUw.sel.every((s) => s.id < 128));
  // more machines than IDs: the rest are refused with a reason, nothing takes a reserved ID
  const many = [...models, ...models, ...models].map(({ m, family }, i) => ({ m: { ...m, key: `${m.key}#${i}` }, family }));
  const over = allocateX20(R, many, true);
  assert.equal(over.sel.length, R.usable.length);
  assert.ok(over.problems.length > 0 && /no free machine ID/.test(over.problems[0]));
});

test('x20 flow: a layout\'s IDs are kept where X.20 gives them out; the others move, with the reason', () => {
  const [a, b, c, d, e, f] = models;
  const free = R.usable;
  const layout: Layout = { format: LAYOUT_FORMAT, base: 'x20', categories: ['GND'], machines: {
    [a.m.key]: { id: free[5], category: 'GND', order: 0 },       // usable: kept
    [b.m.key]: { id: 114, category: 'GND', order: 1 },           // MIDI/control range
    [c.m.key]: { id: 86, category: 'GND', order: 2 },            // X.20's own (INP-CA)
    [d.m.key]: { id: 2, category: 'GND', order: 3 },             // a stock machine's ID
    [e.m.key]: { id: free[5], category: 'GND', order: 4 },       // taken by a
    [f.m.key]: { id: 170, category: 'GND', order: 5 },           // 128 and up, no UW
  } };
  const r = allocateX20(R, models, false, layout);
  const id = (k: string): number => r.sel.find((s) => s.m.key === k)!.id;
  assert.equal(id(a.m.key), free[5]);
  assert.equal(r.sel.find((s) => s.m.key === a.m.key)!.mapped, true);
  const why = (k: string): string => r.moves.find((m) => m.module === models.find((x) => x.m.key === k)!.m.module)!.why;
  assert.match(why(b.m.key), /MIDI\/control/);
  assert.match(why(c.m.key), /X\.20's own/);
  assert.match(why(d.m.key), /own machine there/);
  assert.match(why(e.m.key), /another machine/);
  assert.match(why(f.m.key), /without UW/);
  assert.equal(r.moves.length, 5);
  assert.ok(r.sel.every((s) => R.usable.includes(s.id) && s.id < 128));
  assert.equal(new Set(r.sel.map((s) => s.id)).size, r.sel.length);
  assert.equal(x20IdProblem(R, 193, true), 'X.20 keeps 192 and up for its user machines');
  assert.equal(x20IdProblem(R, free[0], true), null);
});

test('x20 flow: the plan\'s meters -- DSP2 words at the trim, IDs, the new-machine list and the records -- follow trim and selection', () => {
  const kept = trimX20Bank(R, BIG, KEEP);
  const cut = trimX20Bank(R, BIG, TRIM);
  assert.ok(cut.bankEnd < kept.bankEnd && cut.trimmed > 0);
  // the plan counts the words without encoding the bank; the build's encoded bank takes exactly those
  for (const t of [kept, cut]) assert.equal(buildBank(t.samples, t.names).words, t.words);
  const full = planX20(R, kept, packs, { uw: true });
  assert.equal(full.dsp2.fits, false);                        // the stock-length bank leaves no room
  assert.ok(full.problems.length > 0 && !full.ok);
  const p = planX20(R, cut, packs, { uw: true });
  assert.ok(p.ok, p.problems.join('; '));
  assert.ok(p.dsp2.fits && p.dsp2.capacity > full.dsp2.capacity && p.dsp2.demand <= p.dsp2.capacity);
  assert.equal(p.dsp2.capacity - p.dsp2.demand >= p.dsp2.free, true);
  assert.equal(p.e12.freedWords, R.e12.bankEnd - cut.bankEnd);
  assert.deepEqual(p.ids, { used: models.length, available: R.usable.length });
  assert.equal(p.list.used, models.length);
  assert.equal(p.list.room, Math.floor(R.ram.listRoom / 60) - R.ram.stockList.entries);
  assert.deepEqual(p.records, { used: 159 + models.length, cap: 200, stock: 159 });
  // unticking machines lowers every meter
  const fewer = planX20(R, cut, packs, { uw: true, exclude: [models[0].m.module, models[1].m.module] });
  assert.equal(fewer.sel.length, p.sel.length - 2);
  assert.ok(fewer.dsp2.demand < p.dsp2.demand && fewer.records!.used === p.records!.used - 2);
  // no UW: fewer IDs, and the UW-sample models are left out by name
  const noUw = planX20(R, cut, packs, { uw: false });
  assert.equal(noUw.ids.available, R.usable.filter((id) => id < 128).length);
  assert.deepEqual(noUw.leftOut, models.filter(({ m }) => needsUwSamples(m)).map(({ m }) => m.name.trim()));
  // nothing selected: not buildable, with the build's own words
  const none = planX20(R, cut, packs, { uw: true, families: [] });
  assert.equal(none.ok, false);
  assert.match(none.problems.join(), /No machines selected/);
});

test('x20 flow: more machines than X.20 has records for is a problem the page shows (X.20\'s own take at most 159 of 200)', () => {
  const cut = trimX20Bank(R, bank(2000), TRIM);
  const f = file();
  f.ram.stock_record_cap = 200 - 3;
  const p = planX20(parseRecipe(f), cut, packs, { uw: true });
  assert.ok(p.records!.used > p.records!.cap);
  assert.match(p.problems.join(), /machine records/);
  // a recipe without the stock cap: the meter is not computed (the page says so), and no problem is invented
  const g = file();
  delete g.ram.stock_record_cap;
  assert.equal(planX20(parseRecipe(g), cut, packs, { uw: true }).records, null);
  const bad = file();
  bad.ram.stock_record_cap = 201;
  assert.throws(() => parseRecipe(bad), /stock record cap/);
});

test('x20 flow: the menu categories (the default): each machine under its sound category\'s code, in the family that code goes in; a layout moves it', () => {
  const cut = trimX20Bank(R, bank(2000), TRIM);
  const p = planX20(R, cut, packs, { uw: true });
  assert.deepEqual(p.table.categories, X20_CATEGORIES);
  assert.deepEqual(X20_CATEGORIES, ['KIK', 'SNR', 'HAT', 'PRC', 'FM', 'SYN', 'WAV', 'VOX', 'PHY', 'FX', 'OTH']);
  const bd = p.sel.find((s) => s.m.name.trim() === 'VADBD')!;
  assert.equal(p.table.machines[bd.m.key].category, 'KIK');
  assert.equal(p.family[bd.m.key], 'TRX');
  const fx = p.sel.find((s) => s.m.name.trim() === 'NFX4P')!;
  assert.equal(p.table.machines[fx.m.key].category, 'FX');
  assert.equal(p.family[fx.m.key], 'NFX');
  // the user moves the kick to FM: it goes in X.20's EFM family too
  const map: Layout = structuredClone(p.table);
  delete map.uw;
  map.machines[bd.m.key] = { ...map.machines[bd.m.key], category: 'FM' };
  const q = planX20(R, cut, packs, { uw: true, layout: map });
  assert.equal(q.table.machines[bd.m.key].category, 'FM');
  assert.equal(q.family[bd.m.key], 'EFM');
  // a layout an earlier X.20 build carried (X.20's families as categories): each machine gets its sound category
  const old: Layout = { format: LAYOUT_FORMAT, base: 'x20', categories: ['GND', 'TRX', 'EFM', 'NFX'], machines: { [bd.m.key]: { id: bd.id, category: 'EFM', order: 0 } } };
  const o = planX20(R, cut, packs, { uw: true, layout: old });
  assert.equal(o.table.machines[bd.m.key].category, 'KIK');
  assert.equal(o.sel.find((s) => s.m.key === bd.m.key)!.id, bd.id);
  // every code goes in one of X.20's families
  for (const c of X20_CATEGORIES) assert.ok(R.families[R.categoryFamily[c]] !== undefined, c);
});

test('x20 flow: with the categories feature off (--family-menus) the layout editor\'s categories are X.20\'s menu families; a layout moves machines between them and round-trips', () => {
  const cut = trimX20Bank(R, bank(2000), TRIM);
  const off = { categories: false };
  const p = planX20(R, cut, packs, { uw: true, features: off });
  assert.deepEqual(p.menus.map((f) => f.name), Object.keys(R.families));
  assert.deepEqual(p.table.categories, ['GND', 'TRX', 'EFM', 'NFX']);
  assert.equal(p.table.uw, true);
  assert.equal(p.layout, null);                               // no map: the default layout
  // the default families: the recipe's (analog drums TRX, effects NFX)
  const an = p.sel.find((s) => s.family === 'AN')!;
  assert.equal(p.family[an.m.key], 'TRX');
  // the user moves it to EFM and gives it another usable ID
  const map: Layout = structuredClone(p.table);
  delete map.uw;
  const newId = R.usable.find((id) => !p.sel.some((s) => s.id === id))!;
  map.machines[an.m.key] = { id: newId, category: 'EFM', order: 0 };
  const q = planX20(R, cut, packs, { uw: true, layout: map, features: off });
  assert.equal(q.family[an.m.key], 'EFM');
  assert.equal(q.sel.find((s) => s.m.key === an.m.key)!.id, newId);
  assert.ok(q.menus.find((f) => f.name === 'EFM')!.models.some((m) => m.key === an.m.key));
  assert.equal(q.layout!.machines[an.m.key].category, 'EFM');
  // a layout made for another OS: its categories are not X.20's, so the families stay the recipe's
  const other: Layout = { format: LAYOUT_FORMAT, base: 'x20', categories: ['AN'], machines: { [an.m.key]: { id: newId, category: 'AN', order: 0 } } };
  assert.equal(planX20(R, cut, packs, { uw: true, layout: other, features: off }).family[an.m.key], 'TRX');
  // the table the build writes reads back from a .syx: the layout, the IDs and the UW answer
  const table = encodeLayout(q.table);
  const cont = new Uint8Array(0xf0000 - OS_START).fill(0xff);
  const at = E12B_FLASH - OS_START + 0x40000 + 0x1234 * 4;
  cont.set(table, at);
  const back = findX20Layout(encodeSyx(cont), [R.id])!;
  assert.deepEqual(parseLayout(JSON.stringify(back)), parseLayout(JSON.stringify(q.table)));
  // a table for another base (a 1.63-lineage build's) is not taken for an X.20 one; nor is a file without one
  cont.set(encodeLayout({ ...q.table, base: 'x14' }), at);
  assert.equal(findX20Layout(encodeSyx(cont), [R.id]), null);
  assert.equal(findX20Layout(encodeSyx(new Uint8Array(0xf0000 - OS_START)), [R.id]), null);
  assert.equal(findX20Layout(new Uint8Array(10), [R.id]), null);
});

test('x20 flow: the ID map -- usable IDs free, 96..123 silent, X.20\'s own machines (INP 80..85 not reused) and nothing above 191', () => {
  const slots = x20IdSlots(R);
  assert.equal(slots.length, 192);
  assert.deepEqual(slots.filter((s) => s.state === 'free').map((s) => s.id), R.usable);
  assert.ok(slots.filter((s) => s.id >= 96 && s.id <= 123).every((s) => s.state === 'dead'));
  for (const id of [80, 85, 86, 0]) assert.equal(slots[id].state, 'base');
  assert.match(slots[82].why!, /not offered/);
});

test('x20 flow: a project names X.20 B by its file hashes and refuses another OS', () => {
  const os = osOfRecipe(file());
  assert.equal(os.base, 'x20');
  assert.equal(os.coldfire_sha256, file().identify.syx_sha256);
  assert.equal(osProblem(os, os), null);
  assert.match(osProblem({ ...os, base: 'x14', name: 'X.14' }, os)!, /made for X\.14/);
  assert.match(osProblem({ ...os, dsp2_sha256: '00' }, os)!, /different/);
});

// ---- with firmware (MD_FIRMWARE_DIR holding the X.20 B .syx; skipped without it)

const FW = process.env.MD_FIRMWARE_DIR;
const fwSkip = !FW || !existsSync(FW) ? 'MD_FIRMWARE_DIR is not set to a directory of OS files' : false;

test('firmware: X.20 B builds with the user\'s choices -- trim, unticked machines, a layout -- and the build carries its layout', { skip: fwSkip }, async (t) => {
  let syx: Uint8Array | null = null;
  for (const f of readdirSync(FW!).filter((n) => /\.syx$/i.test(n))) {
    const b = readFileSync(join(FW!, f));
    if (recipeFor([file()], await sha256(b))) { syx = b; break; }
  }
  if (!syx) { t.skip('no X.20 B .syx in MD_FIRMWARE_DIR'); return; }
  const { core } = loadPacks([join(ROOT, 'catalog')]);
  const trim = { db: -28, minSeconds: 0.5, cap: 0.6 };
  const plain = await buildX20(syx, file(), packs, core, { uw: true, trim });
  const an = plain.report.machines.find((m) => m.family === 'AN')!;
  const newId = R.usable.find((id) => !plain.report.machines.some((m) => m.id === id))!;
  const map: Layout = { ...plain.report.layout, machines: { ...plain.report.layout.machines, [an.key]: { id: newId, category: 'FM', order: 0 } } };
  delete map.uw;
  const exclude = [models[models.length - 1].m.module];
  const r = await buildX20(syx, file(), packs, core, { uw: true, trim, layout: map, exclude });
  assert.ok(r.report.gates.every((g) => g.ok));
  assert.equal(r.report.machines.find((m) => m.key === an.key)!.id, newId);
  assert.equal(r.report.layout.machines[an.key].category, 'FM');
  // boot-time chunk reads: flash's own address on hardware (the alias froze every build on the first logo), the
  // alias only in the emulator-only upload variant (the emulator reads flash only there at that point)
  assert.ok(plain.report.gates.some((g) => g.ok && /flash at its own address/.test(g.name)), plain.report.gates.map((g) => g.name).join('; '));
  assert.ok(plain.report.flash.chunks_pre.every(([a]) => parseInt(a, 16) < 0x100000));
  const up = await buildX20(syx, file(), packs, core, { uw: true, trim, dsp2Load: 'upload' });
  assert.ok(up.report.gates.some((g) => g.ok && /through the flash alias \(emulator-only/.test(g.name)), up.report.gates.map((g) => g.name).join('; '));
  // the features: unmute, categories and dynamic labels by default; the ID fixes only when an ID needs them
  const fs = (x: typeof r) => x.report.features.map((f) => f.name);
  assert.ok(['unmute', 'categories', 'dyn_labels'].every((f) => fs(plain).includes(f)), fs(plain).join());
  assert.equal(fs(plain).includes('title_rom'), plain.report.machines.some((m) => (m.id >= 128 && m.id <= 159) || (m.id >= 176 && m.id <= 191)));
  assert.equal(fs(plain).includes('id_masks'), plain.report.machines.some((m) => (m.id >= 88 && m.id <= 95) || (m.id >= 114 && m.id <= 127)));
  // each switch takes its feature out (and the categories' title site gives the records site back)
  const none = await buildX20(syx, file(), packs, core, { uw: true, trim, features: { unmute: false, categories: false, dynLabels: false } });
  assert.ok(none.report.gates.every((g) => g.ok));
  assert.ok(!['unmute', 'categories', 'dyn_labels'].some((f) => fs(none).includes(f)), fs(none).join());
  assert.deepEqual(none.report.layout.categories, ['GND', 'TRX', 'EFM', 'NFX']);
  // the recipe gives out no ROM-range ID (128..159, 176..191 are X.20's ROM machines), so the title fix stays out
  assert.ok(!R.usable.some((id) => (id >= 128 && id <= 159) || (id >= 176 && id <= 191)));
  assert.ok(!fs(plain).includes('title_rom'));
  // a machine moved onto a class-masked ID (88..95): the class-mask fix goes in, for that ID
  const free = R.usable.find((id) => id >= 88 && id <= 95 && !plain.report.machines.some((m) => m.id === id))!;
  const k1 = plain.report.machines[0].key;
  const map2: Layout = { ...plain.report.layout, machines: { ...plain.report.layout.machines, [k1]: { ...plain.report.layout.machines[k1], id: free } } };
  delete map2.uw;
  const masked = await buildX20(syx, file(), packs, core, { uw: true, trim, layout: map2 });
  assert.ok(masked.report.gates.every((g) => g.ok));
  assert.ok(fs(masked).includes('id_masks'), fs(masked).join());
  assert.ok(masked.report.notes.some((n) => n.includes(`class-mask fix for IDs`) && n.includes(String(free))), masked.report.notes.join('; '));
  assert.equal(r.report.machines.length, plain.report.machines.length - 1);
  assert.ok(r.report.flash.used <= r.report.flash.capacity && r.report.flash.layout);
  const back = findX20Layout(r.output, [R.id])!;
  assert.equal(back.machines[an.key].id, newId);
  assert.equal(back.uw, true);
});
