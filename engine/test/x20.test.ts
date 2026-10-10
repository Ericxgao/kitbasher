import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { idAllowedOnX20, parseRecipe, recipeFor, type X20RecipeFile } from '../src/x20_recipe.js';
import { cacheOpsIn, dsp2BootLoader, isCode, siteBytes, stageCode, windowA, writeList, x20Map, evalExpr } from '../src/x20_cf.js';
import { buildX20, readX20, trimX20, trimX20Bank, x20E12Bank, x20IsaGate, x20NeighbourReads, NEIGHBOUR_1X, NEIGHBOUR_X20 } from '../src/x20.js';
import { anchorMismatches, preloadConflicts, relocationAudit } from '../src/x20_audit.js';
import { buildBank, decode as e12Decode, encode as e12Encode, freeFlash, readBank, ENTRIES } from '../src/e12b.js';
import { decodeLinear } from '../src/isa.js';
import { loadPacks } from '../src/node.js';
import { sha256 } from '../src/bytes.js';
import { Asm } from '../src/cf_asm.js';

const ROOT = fileURLToPath(new URL('../../../', import.meta.url));
const file = (): X20RecipeFile => JSON.parse(readFileSync(join(ROOT, 'bases/x20.json'), 'utf8'));
const R = parseRecipe(file());

test('x20 recipe: parses, and keeps every model off X.20\'s user-machine IDs (192 and up freeze the OS)', () => {
  assert.equal(R.id, 'x20');
  assert.ok(R.usable.length >= 25);
  assert.ok(R.usable.every((id) => id < 192));
  const f = file();
  f.ids.usable = [...f.ids.usable, 193];
  assert.throws(() => parseRecipe(f), /reserves/);
  const g = file();
  g.ids.usable = [...g.ids.usable, 114];
  assert.throws(() => parseRecipe(g), /reserves/);
  assert.ok(R.usable.every(idAllowedOnX20));
  for (const id of [96, 114, 115, 123, 192, 193, 209]) assert.equal(idAllowedOnX20(id), false);
  for (const id of [95, 124, 191]) assert.equal(idAllowedOnX20(id), true);
});

test('x20 recipe: the USR install/remove/check routines and the E12B erase guard are patched', () => {
  const usr = R.sites.filter((s) => s.group === 'usr').map((s) => s.at);
  for (const a of [0x21780e, 0x217818, 0x2177a0, 0x2177cc, 0x217c24, 0x217c3e, 0x217c44, 0x217c6a, 0x2660a2, 0x2660b2, 0x2660c6, 0x266134, 0x266160, 0x266188])
    assert.ok(usr.includes(a), `USR site ${a.toString(16)}`);
  const erase = R.sites.find((s) => s.at === 0x20da0a)!;
  assert.deepEqual(erase.value, { jmp: 'ERGUARD' });          // only the E12B instance: the +Drive machine banks erase through it too
});

test('x20 recipe: the boot loader stays clear of the machines\' free regions', () => {
  const f = file();
  f.dsp2.free = [['0x147c01', '0x147e00']];
  assert.throws(() => parseRecipe(f), /overlaps the boot loader/);
});

test('x20: recipe expressions', () => {
  const n = { MENU: 0x2fd000, M_U: 0xf5, CAP: 200 };
  assert.equal(evalExpr('MENU+M_U+2', n), 0x2fd0f7);
  assert.equal(evalExpr('CAP-1', n), 199);
  assert.equal(evalExpr('MENU-0x19a8', n), 0x2fd000 - 0x19a8);
  assert.throws(() => evalExpr('NOPE', n), /unknown name/);
});

test('x20: every site is as long as its anchor, and every code site decodes as ISA_A (no move #imm,(d16,An))', () => {
  const M = x20Map(R, 25, 0x124c06);
  const wa = windowA(R, M, new Map([[6, 0], [42, 10]]), Buffer.from('4e75'.repeat(32), 'hex'), 0xe6868);
  const names: Record<string, number> = { STACK: M.stack, RECS: M.recs, CAP: M.cap, MENU: M.menu, M_U: M.mU, M_L: M.mL,
    LIST: M.list, LIST_N: M.listN, BANK_END: 0x124c06, HTAB: wa.htab };
  const code: { at: number; bytes: Uint8Array }[] = [];
  const writes: [number, Uint8Array][] = [];
  for (const s of R.sites) {
    const b = siteBytes(s.value, names, wa.asm.labels);
    assert.equal(b.length, s.old.length, `site ${s.at.toString(16)}`);
    writes.push([s.at, b]);
    if (isCode(s.value)) code.push({ at: s.at, bytes: b });
  }
  const boot = dsp2BootLoader(R);
  const st = stageCode(R, writeList(writes), [0x100ca2dc], [0x100cfe18], wa, boot.receiver);
  const mem = [{ what: 'boot code', ram: R.ram.bootCode[0], bytes: st.asm.bytes }, { what: 'window A', ram: R.ram.window[0], bytes: wa.asm.bytes }];
  const ours = (a: number): boolean => mem.some((m) => a >= m.ram && a < m.ram + m.bytes.length);
  const entries = [st.asm.labels.APPLIER, st.asm.labels.DSP2PRE, ...['VALID', 'FAM', 'CLS', 'GUARD', 'ERGUARD', 'COPYLIST', 'USRCHKREC', 'USRINSMENU', 'USRREM'].map((n) => wa.asm.labels[n]), wa.knobcb];
  const r = x20IsaGate(mem, entries, ours, [...code, ...st.sites]);
  assert.deepEqual(r.rejects.map((i) => `${i.at.toString(16)} ${i.why}`), []);
  assert.ok(r.insns > 300);
  // the negative control: the encoding that froze hardware is refused
  const bad = x20IsaGate([], [], () => false, [{ at: 0x21780e, bytes: Buffer.from('2d7c002fd100ffec', 'hex') }]);
  assert.equal(bad.rejects.length, 1);
  assert.ok(decodeLinear(Buffer.from('4eb9002fc0a04e71', 'hex'), 0).every((i) => i.ok));
});

test('cf_asm: btst #n takes only the ISA_A modes (an absolute address froze hardware)', () => {
  const ok = new Asm(0x1000);
  ok.i('btst', '#0', 'd0'); ok.i('btst', '#1', '2(a5)'); ok.i('rts');
  assert.ok(decodeLinear(ok.assemble().bytes, 0x1000).every((i) => i.ok));
  const bad = new Asm(0x1000);
  bad.i('btst', '#1', '0x600002.l');
  assert.throws(() => bad.assemble(), /static form only/);
});

test('x20: DSP2 boot loader -- receiver and wiper, no cache instruction (they trap on hardware with the cache off)', () => {
  const b = dsp2BootLoader(R);
  assert.equal(b.receiver.length, 38);
  assert.ok(b.receiver.length <= 0x40);
  assert.equal(b.wiper.addr, 0x147d80);
  assert.equal(b.wiper.words[b.wiper.words.length - 1], 0x14f025);
  assert.deepEqual(cacheOpsIn(b.receiver, b.opcodes.receiver), []);
  assert.deepEqual(cacheOpsIn(b.wiper.words, b.opcodes.wiper), []);
  assert.deepEqual(cacheOpsIn([0x000003, 0x0be081, 0x0be080], new Set([0, 1, 2])), [0, 1]);   // pflush, plock (r0); jsr (r0) is not one
});

test('x20: the E12 trim keeps short samples, cuts the quiet tail of long ones with a fade, and pads pairs', () => {
  const long = Array.from({ length: 44100 }, (_, k) => (k < 2000 ? 1000 : 0));      // loud start, silent tail
  const short = Array.from({ length: 1000 }, () => 500);
  const tail = new Array(34).fill(0);
  const enc = (x: number[]): number[] => [...x.map((v) => v & 0xfff), ...tail];
  const { out, trimmed } = trimX20([enc(long), enc(short), null], [], { db: -30, minSeconds: 0.5, cap: null });
  assert.equal(trimmed, 1);
  assert.equal(out[1]!.length, 1000 + 34);
  assert.equal(out[0]!.length, 2000 + 256 + 34);
  assert.equal(out[2], null);
  const paired = trimX20([enc(long), enc(long)], [[0, 1]], { db: -30, minSeconds: 0.5, cap: 0.01 });
  assert.equal(paired.out[0]!.length, paired.out[1]!.length);
});

test('x20: the trim with sample edits -- kept-whole entries, and a swapped first sample padded to its partner, not cutting it', () => {
  const tail = new Array(34).fill(0);
  const enc = (x: number[]): number[] => [...x.map((v) => v & 0xfff), ...tail];
  const first = Array.from({ length: 44100 }, (_, k) => (k < 2000 ? 1000 : 0));      // trims to 2256
  const partner = Array.from({ length: 44100 }, (_, k) => (k < 10000 ? 1000 : 0));   // trims to 10256 alone
  const opt = { db: -30, minSeconds: 0.5, cap: null };
  // stock: the first sample's trim cuts its partner
  const stock = trimX20([enc(first), enc(partner)], [[0, 1]], opt);
  assert.equal(stock.out[1]!.length, 2256 + 34);
  assert.equal(stock.report[1].for_partner, 0);
  // the partner kept whole: not cut, and the first is padded to it
  const kept = trimX20([enc(first), enc(partner)], [[0, 1]], opt, new Set([1]));
  assert.equal(kept.out[1]!.length, 44100 + 34);
  assert.equal(kept.out[0]!.length, 44100 + 34);
  assert.equal(kept.report[0].padded_for, 1);
  // a swapped first sample never cuts its partner: the partner keeps its own trim, the first is padded to it
  const swapped = trimX20([enc(first), enc(partner)], [[0, 1]], opt, new Set(), new Set([0]));
  assert.equal(swapped.out[1]!.length, 10256 + 34);
  assert.equal(swapped.report[1].for_partner, undefined);
  assert.equal(swapped.out[0]!.length, 10256 + 34);
  assert.equal(swapped.report[0].padded_for, 1);
  // no sets: the stock trim, sample for sample
  assert.deepEqual(trimX20([enc(first), enc(partner)], [[0, 1]], opt, new Set(), new Set()).out, stock.out);
});

test('x20: swapped samples go in before the trim -- cut to the stock length with a fade, padded to whole words; a swap equal to stock is stock', () => {
  const tail = new Array(34).fill(0);
  const stockX = Array.from({ length: 2000 }, (_, k) => ((k * 37) % 401) - 200);
  const bank0 = { names: Array.from({ length: 21 }, () => new Uint8Array(4)), samples: Array.from({ length: 21 }, () => [...stockX.map((v) => v & 0xfff), ...tail]) };
  const trim = { db: -40, minSeconds: 5, cap: null };            // nothing is long enough to trim
  const plain = trimX20Bank(R, bank0, trim);
  assert.equal(plain.edits, null);
  const longer = Array.from({ length: 5000 }, () => 1000), odd = Array.from({ length: 999 }, () => -7);
  const t = trimX20Bank(R, bank0, trim, { swaps: new Map<number, number[]>([[3, longer], [4, odd], [5, stockX]]), noTrim: new Set() });
  assert.deepEqual(t.capped, [3]);
  assert.equal(t.samples[3]!.length, 2000 + 34);
  assert.equal(t.samples[3]![0], 1000);
  assert.equal(t.samples[3]![1999], 4);                          // the last of the 256-sample fade: 1000 / 256, rounded
  assert.equal(t.samples[4]!.length, 1000 + 34);                 // 999 samples padded to whole words
  assert.equal(t.samples[4]![0], -7 & 0xfff);
  assert.deepEqual(t.samples[5], plain.samples[5]);
  assert.ok(t.words < plain.words);
  for (const i of [0, 1, 2, 6, 20]) assert.deepEqual(t.samples[i], plain.samples[i]);
  assert.throws(() => trimX20Bank(R, bank0, trim, { swaps: new Map([[21, [1]]]), noTrim: new Set() }), /no INTERNAL entry 21/);
  assert.throws(() => trimX20Bank(R, bank0, trim, { swaps: new Map([[0, [4000]]]), noTrim: new Set() }), /12-bit/);
});

test('x20: the build refuses any file but the one the recipe names', async () => {
  const { packs, core } = loadPacks([join(ROOT, 'catalog')]);
  await assert.rejects(buildX20(new Uint8Array(100), file(), packs, core, { uw: true, trim: { db: -30, minSeconds: 0.5, cap: 0.55 } }), /hash differs/);
});

test('x20: the new-machine list copy refuses an empty selection (its do-while count would wrap and overwrite RAM)', () => {
  assert.throws(() => windowA(R, x20Map(R, 0, 0x124c06), new Map(), new Uint8Array(4), 0xe6868), /at least one machine/);
  assert.doesNotThrow(() => windowA(R, x20Map(R, 1, 0x124c06), new Map([[6, 0]]), new Uint8Array(4), 0xe6868));
});

test('x20: the dispatch upload waits for the pre-boot load to complete (pre_done = 2); the flag is set after the port check', () => {
  const wa = windowA(R, x20Map(R, 1, 0x124c06), new Map([[6, 0]]), new Uint8Array(4), 0xe6868);
  const code = (pre: number[]): string[] => {
    const st = stageCode(R, writeList([]), pre, [0x100cfe18], wa, dsp2BootLoader(R).receiver);
    const L = st.asm.listing;
    const at = (n: string): number => L.findIndex((l) => l.at === st.asm.labels[n]);
    return [...L.slice(at('UPLOAD'), at('UPLOAD') + 6).map((l) => l.text), '|', ...L.slice(at('DSP2PRE'), at('DSP2PRE') + 10).map((l) => l.text)];
  };
  const c = code([0x100ca2dc]);
  assert.deepEqual(c.slice(2, 6), ['move.l @pre_done,d0', 'moveq #2,d1', 'cmp.l d1,d0', 'bne.w up_end']);
  const pre = c.slice(c.indexOf('|'));
  assert.ok(pre.indexOf(`cmpi.l #${R.host.dsp2},d0`) < pre.indexOf('move.l d0,@pre_done'));
  // without a pre-boot load (the emulator's post-start upload) nothing gates the upload
  assert.ok(!code([]).slice(0, 6).includes('move.l @pre_done,d0'));
});

test('e12b: a synthetic bank round-trips through the encoder, the bank layout and the reader', () => {
  const tone = (n: number, f: number): number[] => Array.from({ length: n }, (_, k) => Math.round(1500 * Math.sin(k * f)) & 0xfff);
  const samples: (number[] | null)[] = Array.from({ length: ENTRIES }, (_, i) =>
    i === 3 ? null : i === 5 ? new Array(300).fill(0x7ff) : [...tone(500 + 137 * i, 0.01 * (i + 1)), ...new Array(34).fill(0)]);
  for (const x of samples) if (x) assert.deepEqual(e12Decode(e12Encode(x), x.length), x);
  const names = Array.from({ length: ENTRIES }, (_, i) => Uint8Array.from(Buffer.from(('S' + i).padEnd(4).slice(0, 4))));
  const bank = buildBank(samples, names);
  assert.deepEqual(readBank(bank.area).samples, samples);
  assert.ok(freeFlash(bank).length > 0 && freeFlash(bank).every(([a, b]) => b > a));
});

test('x20: nothing written after the pre-boot load may land on the machines or the boot loader', () => {
  const B = R.dsp2.boot, be = R.e12.table + 3 * R.e12.count;
  const regions: [number, number][] = [[be, R.e12.bankEnd], ...R.dsp2.free];
  assert.deepEqual(preloadConflicts(R, [[0x100000, 0x1025c4], [0x1028c0, 0x135205], [0x146000, 0x147bff], [0x147e00, 0x147f07]], be, regions), []);
  assert.equal(preloadConflicts(R, [[B.wiper + 4, B.wiper + 4]], be, regions).length, 1);
  assert.equal(preloadConflicts(R, [[0x147c10, 0x147c20]], be, regions).length, 1);
});

test('x20: a ping-pong neighbour read (md_output XOR $20) is rewritten for X.20\'s four rotating buffers; nothing else is', () => {
  const code = [0x000000, ...NEIGHBOUR_1X, 0x0c0000, ...NEIGHBOUR_1X];
  const placed = { records: [[0x120000, [...code]] as [number, number[]]], machines: [{ org: 0x120000, words: code.length, name: 'FX   ' }] };
  assert.deepEqual(x20NeighbourReads(placed, []), ['FX (+1)', 'FX (+6)']);
  assert.deepEqual(placed.records[0][1], [0x000000, ...NEIGHBOUR_X20, 0x0c0000, ...NEIGHBOUR_X20]);
  const other = { records: [[0x120000, [0x5ef000, 0x000140, 0x016084, 0x219000]] as [number, number[]]], machines: [{ org: 0x120000, words: 4, name: 'X' }] };
  assert.deepEqual(x20NeighbourReads(other, []), []);
  // the bundled ladder filter reads its neighbour that way, and its pack keeps the base-neutral form
  const { packs } = loadPacks([join(ROOT, 'catalog')]);
  const ladder = packs.flatMap((p) => p.models).find((m) => m.name.trim() === 'NFX4P')!;
  const b = Buffer.from(ladder.code.words, 'base64');
  const w = Array.from({ length: b.length / 3 }, (_, k) => b[3 * k] | (b[3 * k + 1] << 8) | (b[3 * k + 2] << 16));
  assert.deepEqual(w.slice(222, 226), NEIGHBOUR_1X);
});

test('x20: the applier leaves the boot code in X.20\'s heap as zeros before entering the OS', () => {
  const wa = windowA(R, x20Map(R, 1, 0x124c06), new Map([[6, 0]]), new Uint8Array(4), 0xe6868);
  const st = stageCode(R, writeList([]), [0x100ca2dc], [0x100cfe18], wa, dsp2BootLoader(R).receiver);
  const t = st.asm.listing.map((l) => l.text);
  const k = t.indexOf('jsr @UPLOAD');
  assert.deepEqual(t.slice(k + 1, k + 8), ['lea @ap_end,a0', `move.l #${R.ram.bootCode[1]},d1`, 'clr.l (a0)+', 'move.l a0,d0', 'cmp.l d1,d0', 'bcs.b ap_z', `jmp ${'0x' + R.loader.handoff.enter.toString(16)}.l`]);
  assert.ok(st.asm.labels.ap_end > st.asm.labels.APPLIER && st.asm.labels.ap_end < R.ram.bootCode[1]);
});

test('x20: X.20\'s own machines are never usable IDs', () => {
  const f = file();
  f.ids.usable = [...f.ids.usable, 86];
  assert.throws(() => parseRecipe(f), /reserves|X\.20's own/);
});

// ---- offline, against a decoded X.20 B OS image (KB_X20_OS; never committed)

const OS = process.env.KB_X20_OS;
const osSkip = !OS || !existsSync(OS) ? 'KB_X20_OS is not set to a decoded X.20 B ColdFire image' : false;

test('x20 recipe: every anchor holds in X.20 B', { skip: osSkip }, () => {
  assert.deepEqual(anchorMismatches(R, readFileSync(OS!)), []);
});

test('x20 recipe: relocation audit -- every reference to what the recipe moves is patched or explained', { skip: osSkip }, () => {
  const os = readFileSync(OS!);
  const spec = file().audit!;
  assert.deepEqual(relocationAudit(R, os, spec).unexplained, []);
  // the negative control: without the USR sites the routines behind the RECV FAIL are flagged
  const f = file();
  f.sites = f.sites.filter((s) => s.group !== 'usr');
  const r = relocationAudit(parseRecipe(f), os, spec);
  assert.ok(r.unexplained.length >= 10, r.unexplained.join('\n'));
});

const MAP = process.env.KB_X20_DSP_MAP;
const mapSkip = !MAP || !existsSync(MAP) ? 'KB_X20_DSP_MAP is not set to the decoded X.20 B DSP write map' : false;

test('x20: X.20 B\'s own DSP2 load (the decoded write map) never lands on the pre-loaded machines or the boot loader', { skip: mapSkip }, () => {
  const m = JSON.parse(readFileSync(MAP!, 'utf8')) as { dsp2: Record<string, { ranges: [string, string, number][] }> };
  const w = ['P', 'X', 'Y'].flatMap((k) => m.dsp2[k].ranges.map(([a, b]) => [parseInt(a, 16), parseInt(b, 16)] as [number, number])).filter(([a]) => a >= 0x100000);
  const worst = R.e12.table + 3 * R.e12.count;            // no trim frees more than this
  assert.deepEqual(preloadConflicts(R, w, worst, [[worst, R.e12.bankEnd], ...R.dsp2.free]), []);
});

// ---- with firmware (MD_FIRMWARE_DIR holding the X.20 B .syx; skipped without it)

const FW = process.env.MD_FIRMWARE_DIR;
const fwSkip = !FW || !existsSync(FW) ? 'MD_FIRMWARE_DIR is not set to a directory of OS files' : false;

test('firmware: X.20 B builds the bundled catalog, deterministically, with every gate passed', { skip: fwSkip }, async (t) => {
  let syx: Uint8Array | null = null;
  for (const f of readdirSync(FW!).filter((n) => /\.syx$/i.test(n))) {
    const b = readFileSync(join(FW!, f));
    if (recipeFor([file()], await sha256(b))) { syx = b; break; }
  }
  if (!syx) { t.skip('no X.20 B .syx in MD_FIRMWARE_DIR'); return; }
  const { packs, core } = loadPacks([join(ROOT, 'catalog')]);
  const opt = { uw: true, trim: { db: -30, minSeconds: 0.5, cap: 0.55 } };
  const a = await buildX20(syx, file(), packs, core, opt);
  const b = await buildX20(syx, file(), packs, core, opt);
  assert.equal(await sha256(a.output), await sha256(b.output));
  assert.ok(a.report.gates.every((g) => g.ok));
  assert.ok(a.report.machines.every((m) => idAllowedOnX20(m.id) && !(m.id >= 96 && m.id <= 123) && m.id <= 191), a.report.machines.map((m) => m.id).join(','));
  assert.equal(new Set(a.report.machines.map((m) => m.id)).size, a.report.machines.length);
  const noUw = await buildX20(syx, file(), packs, core, { ...opt, uw: false });
  assert.ok(noUw.report.machines.every((m) => m.id < 128));
  // no machine: refused before anything is laid out
  await assert.rejects(buildX20(syx, file(), packs, core, { ...opt, families: [] }), /No machines selected/);
  // one machine
  const modules = [...new Set(packs.flatMap((p) => p.models.map((m) => m.module)))];
  const one = await buildX20(syx, file(), packs, core, { ...opt, exclude: modules.slice(1) });
  assert.equal(one.report.machines.length, 1);
  assert.ok(one.report.gates.every((g) => g.ok));
  // the stock E12 bank, read and encoded again, is the same bytes: the encoder is the stock one
  const { decodeSyx, OS_START } = await import('../src/syx.js');
  const area = decodeSyx(syx).subarray(0x90000 - OS_START, 0xf0000 - OS_START);
  const stock = readBank(area);
  const again = buildBank(stock.samples, stock.names);
  assert.ok(again.entries.every((e, i) => e.bytes === stock.directory.entries[i].bytes && e.crcIn === stock.directory.entries[i].crcIn));
});

test('firmware: X.20 B sample swap -- the bank map, and a swapped entry built into E12B while every other entry is the unswapped build\'s', { skip: fwSkip }, async (t) => {
  let syx: Uint8Array | null = null;
  for (const f of readdirSync(FW!).filter((n) => /\.syx$/i.test(n))) {
    const b = readFileSync(join(FW!, f));
    if (recipeFor([file()], await sha256(b))) { syx = b; break; }
  }
  if (!syx) { t.skip('no X.20 B .syx in MD_FIRMWARE_DIR'); return; }
  const { bank0 } = readX20(syx, R);
  const bank = x20E12Bank(R, bank0);
  assert.equal(bank.entries.length, 21);
  assert.equal(bank.machines.length, 16);
  assert.equal(bank.entries[0].start, 0x103dba);
  assert.equal(bank.entries[17].start, 0x12af33);                 // HT, where X.20's DSP2 stage lays it
  assert.equal(bank.entries[17].samples, 11914 - 34);
  assert.deepEqual(bank.machines.find((m) => m.id === 50), { id: 50, name: 'E12-HT', family: 'E12', entries: [17] });
  assert.deepEqual(bank.entries[12].machines.map((m) => m.name).sort(), ['E12-RS', 'E12-SD']);
  assert.throws(() => x20E12Bank(R, { ...bank0, names: bank0.names.map((n, i) => (i === 3 ? new Uint8Array([0x58, 0x58, 0x20, 0x20]) : n)) }), /not the recipe's/);
  const { packs, core } = loadPacks([join(ROOT, 'catalog')]);
  const modules = [...new Set(packs.flatMap((p) => p.models.map((m) => m.module)))];
  const opt = { uw: true, trim: { db: -30, minSeconds: 0.5, cap: 0.55 }, exclude: modules.slice(1) };
  const sweep = Array.from({ length: 11025 }, (_, k) => Math.round(1800 * Math.sin(2 * Math.PI * 300 * (10 ** (k / 11025) - 1) * 11025 / 44100 / Math.LN10)));
  const plain = await buildX20(syx, file(), packs, core, opt);
  const swapped = await buildX20(syx, file(), packs, core, { ...opt, samples: { swaps: new Map([[17, sweep]]), noTrim: new Set([17]) } });
  assert.ok(swapped.report.gates.every((g) => g.ok));
  assert.deepEqual(swapped.report.e12.edits, { swapped: [17], capped: [], no_trim: [17] });
  assert.equal(plain.report.e12.edits, undefined);
  const { decodeSyx, OS_START } = await import('../src/syx.js');
  const read = (o: Uint8Array) => readBank(decodeSyx(o).subarray(0x90000 - OS_START, 0xf0000 - OS_START));
  const a = read(plain.output), b = read(swapped.output);
  const want = [...sweep.map((v) => v & 0xfff), 0, ...new Array(34).fill(0)];          // 11025 samples padded to whole words, then the silent tail
  assert.deepEqual(b.samples[17], want);
  for (let i = 0; i < 21; i++) if (i !== 17) assert.deepEqual(b.samples[i], a.samples[i], `entry ${i}`);
});
