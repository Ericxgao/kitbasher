// Building on MDX X.20 B (bases/x20.json, engine/src/x20_recipe.ts).
//
// X.20's loader streams its OS through the DSPs and gets the ColdFire image back, so the build never
// sees the OS: it works on the loader's stage image and the E12B sample bank only.
//   1. E12B: the INTERNAL samples trimmed (the 1.63-lineage rule), re-encoded; the DSP2 words and
//      flash they free hold the machines.
//   2. DSP2: the selected machines placed and linked into the freed bank and X.20's free gap; their
//      dispatch words in both X.20 dispatch tables (the stock 193-entry ones and the relocated 211-entry
//      ones its runtime reads).
//   3. The machines' code goes into DSP2 before DSP2's own loader runs (a receiver sent through the
//      bootstrap's ELD); the dispatch words go after DSP2 starts, through the OS's own block write.
//   4. ColdFire: the recipe's sites (record table, menu, stack, new-machine list, hooks) written by
//      an applier once the loader has decoded the OS; the routines they call ride in the stage image.
//   5. The stage image re-packed into slot 0, the payload, list and bank in E12B flash: a .syx.
// Gates (all hard failures): the file is X.20 B by hash; every ColdFire instruction the build adds,
// at its own addresses or at an OS site, decodes as ISA_A (isa.ts); the DSP boot code holds no cache
// instruction (they trap on hardware with the cache off); every site's new bytes are as long as its anchor.

import { be32, concat, h, sha256, sum32, u32 } from './bytes.js';
import { readBank, buildBank, freeFlash, E12B_FLASH, E12B_END, PAD_WORDS, type Bank } from './e12b.js';
import { placeDsp2, type Dsp2Placed, type Dsp2Target } from './dsp2_place.js';
import { decodeLinear, scanCode, type CodeMem, type Insn } from './isa.js';
import { nrv2bDecode } from './nrv2b.js';
import type { CorePack, Pack, PackModel, PackTable } from './packs.js';
import { needsUwSamples } from './packs.js';
import { select, type Family, type IdMove, type Selected } from './selection.js';
import { decodeSyx, encodeSyx, OS_START } from './syx.js';
import { uclPack } from './ucl.js';
import { cacheOpsIn, dsp2BootLoader, isCode, siteBytes, stageCode, windowA, writeList, x20Map } from './x20_cf.js';
import { idAllowedOnX20, parseRecipe, type X20Recipe, type X20RecipeFile } from './x20_recipe.js';
import { fromBase64 } from './bytes.js';
import { decodeLayout, encodeLayout, LAYOUT_FORMAT, type IdSlot, type Layout, type MachinePlace } from './layout.js';
import { capSamples, NO_EDITS, type BankEntry, type E12Bank, type E12Machine, type SampleEdits } from './samples.js';
import type { TrimEntry } from './e12.js';

export interface X20Options {
  /** a Machinedrum with the UW option (machines on 128 and up, and the UW-sample machines, need it) */
  uw: boolean;
  families?: string[];
  exclude?: string[];
  /** the E12 trim: samples quieter than `db` below their peak at the end are cut (after `minSeconds`), at most `cap` seconds kept */
  trim: { db: number; minSeconds: number; cap: number | null };
  align?: boolean;
  /**
   * How the machines' code reaches DSP2. 'preboot' (the default, the one real hardware runs): through DSP2's
   * bootstrap before its loader and runtime start. 'upload': all of it after DSP2 starts, through the OS's
   * block write -- for the emulator only (its DSP JIT does not see code written through X space before it
   * runs); on hardware a big upload there makes the OS miss DSP2's startup messages.
   */
  dsp2Load?: 'preboot' | 'upload';
  /**
   * The user's layout (md-layout/1, base = the recipe's id): a mapped machine takes its map ID when X.20
   * allows it (a usable ID, below 128 without UW, not taken) and its map category when that is one of
   * X.20's menu families. Without one, IDs go bottom-up and families by the recipe's rules.
   */
  layout?: Layout;
  /** the user's E12 samples (engine/src/samples.ts): swapped entries and entries the trim leaves whole */
  samples?: SampleEdits;
}

export interface X20Report {
  base: string;
  machines: { name: string; key: string; id: number; family: string; org: string; words: number }[];
  e12: { bank_end: string; words: number; stock_words: number; freed_words: number; flash_end: string; trimmed: number;
    /** present only with sample edits: the swapped entries, those cut to their stock length, and those kept whole */
    edits?: { swapped: number[]; capped: number[]; no_trim: number[] } };
  dsp2: { capacity: number; demand: number; free: number; regions: [string, string][] };
  flash: { chunks_pre: [string, number][]; chunks_post: [string, number][]; list: string; free_left: number;
    /** E12B flash the trimmed bank leaves free, and what the machines' code, the list and the layout table take of it */
    capacity: number; used: number; layout: string | null };
  /** the layout the build carries (in E12B flash after the list) and X.20's menu families with the machines added to each */
  layout: Layout;
  menus: { name: string; machines: string[] }[];
  /** machines the layout put on IDs X.20 cannot give them, and the IDs they took */
  moves: IdMove[];
  stage: { boot_code: string; window: string; packed: number; room: number };
  gates: { name: string; ok: boolean; detail: string }[];
  notes: string[];
}

const SR = 44100, FADE = 256, LEN_EXTRA = 34;
const RAW_MAX_DEFAULT = 0x2b000;

/**
 * The E12 trim (the 1.63-lineage rule, on X.20's decoded samples): per entry the new 12-bit samples, and per
 * entry a report row as engine/src/e12.ts trimBank gives it. `noTrim` and `swapped` as there: entries in
 * `noTrim` keep their length (and the pair rule does not shorten them); a swapped first sample never cuts its
 * partner and is padded to it instead. With neither set this is the stock X.20 trim, sample for sample.
 */
export function trimX20(samples: (number[] | null)[], pairs: [number, number][], opt: X20Options['trim'],
  noTrim: ReadonlySet<number> = new Set(), swapped: ReadonlySet<number> = new Set()): { out: (number[] | null)[]; trimmed: number; report: TrimEntry[] } {
  const thr = 10 ** (opt.db / 20);
  const sgn = (v: number): number => (v >= 2048 ? v - 4096 : v);
  const xs = samples.map((s) => {
    if (!s) return null;
    if (s.length < LEN_EXTRA || s.slice(s.length - LEN_EXTRA).some((v) => v !== 0)) throw new Error('E12B: an entry without its silent tail');
    return s.slice(0, s.length - LEN_EXTRA).map(sgn);
  });
  const keeps = xs.map((x, i) => {
    if (!x) return 0;
    const n = x.length;
    let keep = n;
    if (!noTrim.has(i) && n / SR >= opt.minSeconds) {
      const limit = Math.max(...x.map(Math.abs)) * thr;
      let q = n;
      for (let k = n - 1; k >= 0; k--) { if (Math.abs(x[k]) < limit) q = k; else break; }
      if (q < n) keep = Math.min(n, q + FADE);
      if (opt.cap) keep = Math.min(keep, Math.max(Math.floor(opt.cap * SR), FADE));
    }
    return keep;
  });
  const wo = (k: number): number => (k + 1) >> 1;
  const padTo = xs.map(() => 0);
  const forPartner: (number | undefined)[] = xs.map(() => undefined);
  const paddedFor: (number | undefined)[] = xs.map(() => undefined);
  for (let changed = true; changed;) {
    changed = false;
    for (const [a, b] of pairs) {
      if (!xs[a] || !xs[b] || keeps[a] >= xs[a]!.length) continue;   // first sample untrimmed: stock behaviour
      if (swapped.has(a) || noTrim.has(b)) continue;                    // the user's first / a partner kept whole: padded below
      if (wo(keeps[b]) > wo(keeps[a])) { keeps[b] = keeps[a]; forPartner[b] = a; changed = true; }
    }
  }
  for (const [a, b] of pairs) {
    if (xs[a] && xs[b] && wo(keeps[b]) > wo(Math.max(keeps[a], padTo[a]))) { padTo[a] = 2 * wo(keeps[b]); paddedFor[a] = b; }
  }
  const rhe = (v: number): number => { const f = Math.floor(v), d = v - f; return d > 0.5 || (d === 0.5 && f % 2 !== 0) ? f + 1 : f; };
  const r3 = (v: number): number => Math.round(v * 1000) / 1000;
  let trimmed = 0;
  const report: TrimEntry[] = [];
  const out = xs.map((x, i) => {
    if (!x) return null;
    const n = x.length, keep = keeps[i];
    let y = x;
    if (!(keep >= n && padTo[i] <= n)) {
      trimmed++;
      y = x.slice(0, keep);
      if (keep < n) {
        const f = Math.min(FADE, keep), step = -1 / f;
        for (let k = 0; k < f; k++) { const j = keep - f + k; y[j] = rhe(y[j] * (k * step + 1)); }
      }
      while (y.length < padTo[i]) y.push(0);
      if (y.length % 2) y.push(0);
    }
    const row: TrimEntry = { entry: i, seconds: r3(n / SR), kept: r3(y.length / SR), words: wo(n), new_words: wo(y.length) };
    if (forPartner[i] !== undefined) row.for_partner = forPartner[i];
    if (paddedFor[i] !== undefined) row.padded_for = paddedFor[i];
    report.push(row);
    return [...y.map((v) => v & 0xfff), ...new Array(LEN_EXTRA).fill(0)];
  });
  return { out, trimmed, report };
}

/**
 * The stock E12B bank as the Samples step shows it (engine/src/samples.ts E12Bank): every entry, its samples
 * and the machines that play it. Which machine plays which entry is the recipe's (read from X.20's DSP2
 * dispatch, bases/x20.json e12.machines); the entry names in E12B must be the recipe's, or this throws. Start
 * addresses are where X.20's DSP2 stage lays the stock bank (each entry: its data words, the 34-sample silent
 * tail, the pad).
 */
export function x20E12Bank(R: X20Recipe, bank0: { names: Uint8Array[]; samples: (number[] | null)[] }): E12Bank {
  const E = R.e12;
  const names = bank0.names.map((n) => String.fromCharCode(...n).trim());
  if (names.length !== E.count || E.names.length !== E.count || names.some((n, i) => n !== E.names[i])) {
    throw new Error(`${R.name}: the INTERNAL bank's entries are not the recipe's (${names.join(' ')})`);
  }
  for (const m of E.machines) for (const e of m.entries) if (!Number.isInteger(e) || e < 0 || e >= E.count) throw new Error(`${R.name}: ${m.name} plays no entry ${e}`);
  const machines: E12Machine[] = E.machines.map((m) => ({ id: m.id, name: m.name, family: 'E12', entries: [...m.entries] }));
  const sgn = (v: number): number => (v >= 2048 ? v - 4096 : v);
  let start = E.table + 3 * E.count;
  const entries: BankEntry[] = bank0.samples.map((s, i) => {
    if (!s) throw new Error(`${R.name}: INTERNAL entry ${i} (${names[i]}) is empty`);
    const n = s.length - LEN_EXTRA, words = Math.ceil(n / 2);
    const e: BankEntry = {
      entry: i, start, words, samples: 2 * words, data: Int16Array.from(s.slice(0, n).map(sgn)),
      machines: machines.filter((m) => m.entries.includes(i)),
      pairs: E.pairs.flatMap(([a, b]): { partner: number; first: boolean }[] => (a === i ? [{ partner: b, first: true }] : b === i ? [{ partner: a, first: false }] : [])),
    };
    start += Math.ceil(s.length / 2) + PAD_WORDS;
    return e;
  });
  if (start !== E.bankEnd) throw new Error(`${R.name}: the INTERNAL bank lays out to ${h(start)}, not ${h(E.bankEnd)}`);
  return { entries, machines, pairs: E.pairs, stockWords: E.bankEnd - (E.table + 3 * E.count) };
}

/** X.20's menu family for a model: the layout's category when it is one of X.20's families, else the recipe's
 *  per-key-prefix map, its per-pack map, else its default. */
export function menuFamilyName(R: X20Recipe, s: Selected, layout?: Layout): string {
  const want = layout?.machines[s.m.key]?.category;
  if (want !== undefined && R.families[want] !== undefined) return want;
  const byKey = R.file.key_menu ?? {};
  const pref = Object.keys(byKey).find((p) => s.m.key.startsWith(p));
  return pref ? byKey[pref] : (R.file.pack_menu ?? {})[s.family] ?? (R.file.pack_menu ?? {})['*'] ?? 'GND';
}

function menuFamily(R: X20Recipe, s: Selected, layout?: Layout): number {
  const name = menuFamilyName(R, s, layout);
  const f = R.families[name];
  if (f === undefined) throw new Error(`recipe ${R.id}: no menu family ${name}`);
  return f;
}

/** Why a layout's ID cannot be used on X.20 for this machine, or null. */
export function x20IdProblem(R: X20Recipe, id: number, uw: boolean): string | null {
  if (!idAllowedOnX20(id)) return id > 191 ? 'X.20 keeps 192 and up for its user machines' : 'X.20 treats 96..123 as MIDI/control machines (silent)';
  if ((R.file.ids.x20_own ?? []).includes(id)) return "it is one of X.20's own machines";
  if (!R.usable.includes(id)) return 'X.20 has its own machine there';
  if (!uw && id >= 128) return 'no IDs of 128 and up without UW';
  return null;
}

/**
 * IDs from the recipe's usable list (without UW: below 128 only), in catalog order. A layout's ID is
 * kept when X.20 allows it and no machine before it took it; every other machine takes the lowest free
 * one (bottom-up), and a mapped machine that could not keep its ID is listed as a move.
 */
export function allocateX20(R: X20Recipe, models: { m: PackModel; family: string }[], uw: boolean, layout?: Layout): { sel: Selected[]; moves: IdMove[]; problems: string[] } {
  const allowed = R.usable.filter((id) => uw || id < 128);
  const problems: string[] = [];
  const moves: IdMove[] = [];
  const got: (Selected | null)[] = models.map(() => null);
  const taken = new Set<number>();
  const why = new Map<number, string>();
  if (layout) {
    models.forEach(({ m, family }, i) => {
      const want = layout.machines[m.key]?.id;
      if (want === undefined) return;
      const bad = x20IdProblem(R, want, uw) ?? (taken.has(want) ? 'another machine has it' : null);
      if (bad) { why.set(i, bad); return; }
      taken.add(want);
      got[i] = { m, family, id: want, preferred: want, mapped: true };
    });
  }
  const free = allowed.filter((id) => !taken.has(id));
  models.forEach(({ m, family }, i) => {
    if (got[i]) return;
    const id = free.shift();
    if (id === undefined) { problems.push(`no free machine ID left on ${R.name} for ${m.name.trim()}: untick a machine`); return; }
    const want = layout?.machines[m.key]?.id;
    got[i] = { m, family, id, preferred: want ?? m.id, mapped: false };
    if (want !== undefined) moves.push({ name: m.name, module: m.module, preferred: want, id, why: why.get(i) ?? 'its ID was not free' });
  });
  const sel = got.filter((s): s is Selected => !!s);
  for (const s of sel) if (!idAllowedOnX20(s.id)) throw new Error(`${s.m.name.trim()}: ID ${s.id} is one X.20 reserves`);
  return { sel, moves, problems };
}

/** A list entry (X.20's new-machine list format, 60 bytes): ID, name, knob labels, defaults, label mask. */
function listEntry(s: Selected): Uint8Array {
  const e = new Uint8Array(60);
  e[0] = s.id;
  const name = s.m.name.slice(0, 5).padEnd(5);
  for (let k = 0; k < 5; k++) e[1 + k] = name.charCodeAt(k) & 0xff;
  let mask = 0;
  s.m.labels.forEach((l, i) => {
    if (!l) return;
    for (let k = 0; k < Math.min(4, l.length); k++) e[7 + 5 * i + k] = l.charCodeAt(k) & 0xff;
    mask |= 1 << (28 - 4 * i);
  });
  s.m.defaults.forEach((v, i) => { e[0x2f + i] = v & 0x7f; });
  e.set(be32(mask >>> 0), 0x38);
  return e;
}

function blocks(mem: Map<number, number>): [number, number[]][] {
  const out: [number, number[]][] = [];
  for (const a of [...mem.keys()].sort((x, y) => x - y)) {
    const last = out[out.length - 1];
    if (last && a === last[0] + last[1].length) last[1].push(mem.get(a)!);
    else out.push([a, [mem.get(a)!]]);
  }
  return out;
}

const chunkRaw = (blks: [number, number[]][]): Uint8Array =>
  concat(blks.flatMap(([a, ws]) => [be32(a), be32(ws.length), Uint8Array.from(ws.flatMap((w) => [(w >> 16) & 0xff, (w >> 8) & 0xff, w & 0xff]))]));

/** NRV2B chunks of whole (sub)blocks, raw <= rawMax, laid into the flash spans from `cursor` on. */
async function chunks(blks: [number, number[]][], spans: [number, number][], rawMax: number, capacity: number): Promise<{ at: number; packed: Uint8Array }[]> {
  const words: [number, number][] = blks.flatMap(([a, ws]) => ws.map((w, k) => [a + k, w] as [number, number]));
  const out: { at: number; packed: Uint8Array }[] = [];
  let i = 0, si = 0, cur = spans.length ? spans[0][0] : 0;
  while (i < words.length) {
    if (si >= spans.length) {
      // every span is full: what is left, packed about as well as what went in so far
      const packed = out.reduce((n, c) => n + c.packed.length, 0);
      const ratio = i ? packed / (3 * i) : 0.6;
      throw new X20FlashError(capacity + Math.ceil(3 * (words.length - i) * ratio), capacity,
        `the machines' code does not fit the flash the E12 trim frees: ${words.length - i} words left; trim harder or untick a machine`);
    }
    const room = spans[si][1] - cur;
    let n = Math.min(words.length - i, Math.floor(rawMax / 3) - 64);
    let pk: Uint8Array;
    for (;;) {
      let raw = chunkRaw(blocks(new Map(words.slice(i, i + n))));
      while (raw.length > rawMax) { n = Math.floor(n * 0.95); raw = chunkRaw(blocks(new Map(words.slice(i, i + n)))); }
      pk = await uclPack(raw, 10);
      if (nrv2bDecode(pk).out.length !== raw.length) throw new Error('NRV2B round trip');
      if (pk.length <= room || n < 256) break;
      n = Math.floor(n * Math.min(0.97, room / pk.length));
    }
    if (pk.length > room) { si++; if (si < spans.length) cur = spans[si][0]; continue; }
    out.push({ at: cur, packed: pk });
    cur = (cur + pk.length + 1) & ~1;
    spans[si] = [cur, spans[si][1]];
    i += n;
  }
  return out;
}

/**
 * A machine that reads the previous track's output as the other of two ping-pong buffers
 * (`move y:>md_output,a / eor #$20,a / move a1,r0`, as on 1.63 and X.14) reads the wrong buffer on X.20,
 * which rotates four output buffers through the slot ring y:$7e0..$7ef: y:$7f0 holds the current
 * slot's address and each slot is [current, previous, 2 back, 3 back], so the previous track's buffer
 * is y:(y:$7f0 + 1). The four words are rewritten in the linked code (the base-neutral pack is untouched):
 * `move y:>$7f0,r0 / move (r0)+ / move y:(r0),r0` (the DSP56300 interlocks the AGU use of r0).
 */
export const NEIGHBOUR_1X = [0x5ef000, 0x000140, 0x016083, 0x219000];
export const NEIGHBOUR_X20 = [0x68f000, 0x0007f0, 0x205800, 0x68e000];
export function x20NeighbourReads(placed: { records: [number, number[]][]; machines: { org: number; words: number; name: string }[] }, notes: string[]): string[] {
  const out: string[] = [];
  for (const m of placed.machines) {
    const rec = placed.records.find(([a, ws]) => a === m.org && ws.length === m.words);
    if (!rec) continue;
    const ws = rec[1];
    for (let k = 0; k + 4 <= ws.length; k++) {
      if (NEIGHBOUR_1X.every((w, j) => ws[k + j] === w)) { ws.splice(k, 4, ...NEIGHBOUR_X20); out.push(`${m.name.trim()} (+${k})`); k += 3; }
    }
  }
  void notes;
  return out;
}

/** ISA_A over everything the build adds to the ColdFire: our routines from their entries, and every OS site's code bytes. */
export function x20IsaGate(mem: CodeMem[], entries: number[], ours: (a: number) => boolean, siteCode: { at: number; bytes: Uint8Array }[]): { insns: number; rejects: Insn[] } {
  const r = scanCode(mem, entries, ours);
  const rejects = [...r.rejects];
  let insns = r.insns.size;
  for (const s of siteCode) {
    const d = decodeLinear(s.bytes, s.at);
    insns += d.length;
    rejects.push(...d.filter((i) => !i.ok));
    const end = d.reduce((n, i) => n + i.len, 0);
    if (end !== s.bytes.length) rejects.push({ at: s.at, len: s.bytes.length, name: 'site', ok: false, why: `site bytes do not end on an instruction (${end} of ${s.bytes.length})` } as Insn);
  }
  return { insns, rejects };
}

/** Thrown when the machines' code, the new-machine list or the layout table do not fit the E12B flash the trim frees. */
export class X20FlashError extends Error {
  constructor(readonly used: number, readonly capacity: number, detail: string) {
    super(detail);
    this.name = 'X20FlashError';
  }
}

/** The OS container of an X.20 file (its length checked) and its stock E12B bank. */
export function readX20(input: Uint8Array, R: X20Recipe): { cont: Uint8Array; areaOff: number; bank0: ReturnType<typeof readBank> } {
  const container = decodeSyx(input);
  if (container.length !== R.file.identify.container_bytes) throw new Error(`${R.name}: container is ${container.length} bytes, expected ${R.file.identify.container_bytes}`);
  const cont = Uint8Array.from(container);
  const areaOff = E12B_FLASH - OS_START;
  return { cont, areaOff, bank0: readBank(cont.subarray(areaOff, areaOff + (E12B_END - E12B_FLASH))) };
}

/**
 * The E12B bank at one trim: its samples, the DSP2 words it takes, where it now ends in DSP2, and what it
 * frees. Encoding it for flash (buildBank) is left to the build: the plan, and the auto trim that plans at
 * many thresholds, need the words only.
 */
export interface X20Trimmed {
  trim: X20Options['trim'];
  samples: (number[] | null)[];
  names: Uint8Array[];
  words: number;
  bankEnd: number;
  stockWords: number;
  trimmed: number;
  /** per entry, as engine/src/e12.ts trimBank reports it (the Samples step's badges) */
  report: TrimEntry[];
  /** the sample edits this bank was laid with (null: stock), and the swaps cut to their stock length */
  edits: SampleEdits | null;
  capped: number[];
}

/** DSP2 words of a bank: per sample its 16-bit words and its silent pad (as buildBank lays it). */
export const bankWords = (samples: (number[] | null)[]): number => samples.reduce((n, x) => n + (x ? Math.ceil(x.length / 2) + PAD_WORDS : 0), 0);

/**
 * The bank at one trim, with the user's samples in place first (as engine/src/plan.ts does on the 1.63
 * lineage): a swap is cut to its entry's stock length (fading the last 256 samples out), padded to whole
 * words, and then trimmed like any sample unless the entry is in `noTrim`. A swap equal to the stock data
 * is stock. The bank never grows past its stock footprint.
 */
export function trimX20Bank(R: X20Recipe, bank0: { names: Uint8Array[]; samples: (number[] | null)[] }, trim: X20Options['trim'],
  edits: SampleEdits = NO_EDITS): X20Trimmed {
  let samples = bank0.samples;
  const capped: number[] = [], swapped = new Set<number>();
  if (edits.swaps.size) {
    samples = bank0.samples.slice();
    for (const [i, s] of edits.swaps) {
      const stock = Number.isInteger(i) ? bank0.samples[i] : undefined;
      if (!stock) throw new Error(`no INTERNAL entry ${i}`);
      const c = capSamples(s, stock.length - LEN_EXTRA);
      if (c.capped) capped.push(i);
      const y = c.data.map((v) => v & 0xfff);
      if (y.length % 2) y.push(0);
      const next = [...y, ...new Array(LEN_EXTRA).fill(0)];
      if (next.length !== stock.length || next.some((v, k) => v !== stock[k])) { samples[i] = next; swapped.add(i); }
    }
  }
  for (const i of edits.noTrim) if (!Number.isInteger(i) || !bank0.samples[i]) throw new Error(`no INTERNAL entry ${i}`);
  const { out, trimmed, report } = trimX20(samples, R.e12.pairs, trim, edits.noTrim, swapped);
  const words = bankWords(out);
  const dataStart = R.e12.table + 3 * R.e12.count;
  const bankEnd = dataStart + words;
  if (bankEnd > R.e12.bankEnd) throw new Error('E12: the re-encoded bank is longer than the stock one');
  const edited = edits.swaps.size > 0 || edits.noTrim.size > 0;
  return { trim, samples: out, names: bank0.names, words, bankEnd, stockWords: R.e12.bankEnd - dataStart, trimmed, report,
    edits: edited ? { swaps: new Map(edits.swaps), noTrim: new Set(edits.noTrim) } : null, capped: capped.sort((a, b) => a - b) };
}

/** What a selection takes on X.20, without building: the plan the page's meters, layout editor and build share. */
export interface X20Plan {
  ok: boolean;
  /** why it cannot be built, in words a user can act on */
  problems: string[];
  notes: string[];
  /** the machines in list order (the catalog's), with their IDs */
  sel: Selected[];
  shared: PackTable[];
  /** machines the layout put on IDs X.20 cannot give them, and where they went */
  moves: IdMove[];
  /** X.20's menu families in the recipe's order, each with the machines added to it */
  menus: Family[];
  /** the family each machine goes in, by key */
  family: Record<string, string>;
  /** the layout this build has: the map merged with every placement; null without a map */
  layout: Layout | null;
  /** the layout the build writes to flash (the map's, or the default one), with the UW answer */
  table: Layout;
  /** machines left out because they play UW samples (no UW) */
  leftOut: string[];
  workspace: boolean;
  e12: { bankEnd: number; words: number; stockWords: number; freedWords: number; trimmed: number };
  /** the bank this plan was made with (its trim, sample edits and per-entry report) */
  bank: X20Trimmed;
  dsp2: { fits: boolean; capacity: number; demand: number; free: number; regions: [number, number][]; placed: Dsp2Placed };
  /** machine IDs: taken by the selection, and the ones X.20 has for added machines (without UW: below 128) */
  ids: { used: number; available: number };
  /** the new-machine list: entries the selection adds, and its room */
  list: { used: number; room: number };
  /**
   * The ColdFire machine records: X.20's own (at most its stock cap) plus one per added machine, against
   * the cap the build raises. null when the recipe does not give X.20's stock cap.
   */
  records: { used: number; cap: number; stock: number } | null;
}

export function planX20(R: X20Recipe, t: X20Trimmed, packs: Pack[], opt: Omit<X20Options, 'trim'> & { link?: boolean }): X20Plan {
  const notes: string[] = [];
  const problems: string[] = [];
  const { fams, shared } = select(packs, { families: opt.families, exclude: opt.exclude });
  let models = fams.flatMap((f) => f.models.map((m) => ({ m, family: f.name })));
  const leftOut: string[] = [];
  if (!opt.uw) {
    const out = models.filter(({ m }) => needsUwSamples(m));
    leftOut.push(...out.map(({ m }) => m.name.trim()));
    if (out.length) notes.push(`left out (they play UW samples): ${leftOut.join(', ')}`);
    models = models.filter(({ m }) => !needsUwSamples(m));
  }
  if (!models.length) problems.push('No machines selected: tick at least one machine to build for X.20');
  const { sel, moves, problems: idProblems } = allocateX20(R, models, opt.uw, opt.layout);
  problems.push(...idProblems);
  const D = R.dsp2;
  const T: Dsp2Target = { name: R.name, dispatch: D.dispatch, workspace: D.workspace, bankEnd: R.e12.bankEnd, pi: D.pi,
    runtime: { ok: true } };
  const workspace = sel.some((s) => s.m.workspace);
  const firstEnd = workspace ? D.workspace.base : R.e12.bankEnd;
  const wsProblem = workspace && t.bankEnd > D.workspace.base;
  if (wsProblem) problems.push(`the machines' per-track workspace starts at ${h(D.workspace.base)} and the E12 bank ends at ${h(t.bankEnd)}: trim harder`);
  const regions: [number, number][] = [[t.bankEnd, firstEnd], ...D.free];
  const placed = placeDsp2(T, regions, sel, shared, { link: opt.link ?? false, align: opt.align ?? false }, problems, notes);
  // the new-machine list (60-byte entries after X.20's own; its count is a moveq) and the records
  const SL = R.ram.stockList;
  const listRoom = Math.min(Math.floor(R.ram.listRoom / SL.entryBytes), 127) - SL.entries;
  if (sel.length > listRoom) problems.push(`X.20's new-machine list has room for ${listRoom} added machines: untick ${sel.length - listRoom}`);
  const stockCap = R.file.ram.stock_record_cap;
  const records = stockCap === undefined ? null : { used: stockCap + sel.length, cap: R.ram.recordCap, stock: stockCap };
  if (records && records.used > records.cap) {
    problems.push(`X.20's own machines can fill up to ${records.stock} of the ${records.cap} machine records, which leaves room for ${records.cap - records.stock} added machines: untick ${records.used - records.cap}`);
  }
  // families and the layout
  const familyNames = Object.keys(R.families);
  const family: Record<string, string> = {};
  for (const s of sel) family[s.m.key] = menuFamilyName(R, s, opt.layout);
  const menus: Family[] = familyNames.map((name) => ({ name, models: sel.filter((s) => family[s.m.key] === name).map((s) => s.m) }));
  const machines: Record<string, MachinePlace> = {};
  if (opt.layout) {
    // the map's other machines (not selected now) keep their places when they name an X.20 family
    for (const [k, m] of Object.entries(opt.layout.machines)) if (R.families[m.category] !== undefined) machines[k] = { ...m };
  }
  const idOf = new Map(sel.map((s) => [s.m.key, s.id]));
  for (const f of menus) f.models.forEach((m, i) => { machines[m.key] = { id: idOf.get(m.key)!, category: f.name, order: i }; });
  const merged: Layout = { format: LAYOUT_FORMAT, base: R.id, categories: familyNames, machines };
  const layout = opt.layout ? { ...merged, ...(opt.layout.uw === undefined ? {} : { uw: opt.layout.uw }) } : null;
  const fits = placed.overflow === null && !wsProblem;
  return {
    ok: !problems.length, problems, notes, sel, shared, moves, menus, family, layout, table: { ...merged, uw: opt.uw }, leftOut, workspace,
    e12: { bankEnd: t.bankEnd, words: t.words, stockWords: t.stockWords, freedWords: R.e12.bankEnd - t.bankEnd, trimmed: t.trimmed },
    bank: t,
    dsp2: { fits, capacity: placed.capacity, demand: placed.demand, free: placed.free, regions, placed },
    ids: { used: sel.length, available: R.usable.filter((id) => opt.uw || id < 128).length },
    list: { used: sel.length, room: listRoom },
    records,
  };
}

/**
 * Every machine ID 0..191 as X.20 B has it, for the layout editor: the recipe's usable IDs are free;
 * 96..123 are its MIDI/control range; the rest are its own machines.
 */
export function x20IdSlots(R: X20Recipe): IdSlot[] {
  const own = new Set(R.file.ids.x20_own ?? []);
  const usable = new Set(R.usable);
  const out: IdSlot[] = [];
  for (let id = 0; id < 192; id++) {
    if (usable.has(id)) out.push({ id, state: 'free' });
    else if (id >= 96 && id <= 123) out.push({ id, state: 'dead', why: `${R.name} treats 96..123 as MIDI/control machines: a model there plays nothing` });
    else if (own.has(id)) out.push({ id, state: 'base', name: 'X.20', why: `${R.name}'s own machine (its DSP2 dispatch entries must stay)` });
    else if (id >= 80 && id <= 85) out.push({ id, state: 'base', name: 'INP', why: `${R.name}'s INP machine: reusing 80..85 is not offered (the stock INP machine would stay in the menu on the same ID)` });
    else out.push({ id, state: 'base', name: 'X.20', why: `${R.name}'s own machine` });
  }
  return out;
}

const MDLY = [0x4d, 0x44, 0x4c, 0x59];
/**
 * The layout table an X.20 build carries (in E12B flash, after the new-machine list), from the built
 * .syx; null when there is none, or when the table found is not for one of these recipes' OS.
 */
export function findX20Layout(file: Uint8Array, recipeIds: string[]): Layout | null {
  let cont: Uint8Array;
  try { cont = decodeSyx(file); } catch { return null; }
  const lo = E12B_FLASH - OS_START, hi = Math.min(cont.length, E12B_END - OS_START);
  for (let e = hi; e >= lo + 20; e--) {
    if (MDLY.some((v, i) => cont[e - 4 + i] !== v)) continue;
    const n = u32(cont, e - 8);
    if (n < 20 || e - n < lo || MDLY.some((v, i) => cont[e - n + i] !== v)) continue;
    try {
      const l = decodeLayout(cont.subarray(e - n, e));
      if (recipeIds.includes(l.base)) return l;
    } catch { /* not a table */ }
  }
  return null;
}

export async function buildX20(input: Uint8Array, recipeFile: X20RecipeFile, packs: Pack[], core: CorePack, opt: X20Options): Promise<{ output: Uint8Array; report: X20Report }> {
  const R = parseRecipe(recipeFile);
  if (await sha256(input) !== R.file.identify.syx_sha256) throw new Error(`not ${R.name} (the .syx hash differs): this recipe patches that exact file only`);
  const gates: X20Report['gates'] = [];
  const { cont, areaOff, bank0 } = readX20(input, R);
  const at = (flash: number): number => flash - OS_START;

  // ---- 1. E12B, 2. machines: selection, IDs, DSP2 placement (planX20)
  const t = trimX20Bank(R, bank0, opt.trim, opt.samples ?? NO_EDITS);
  const { bankEnd, stockWords, trimmed: nTrim } = t;
  const bank: Bank = buildBank(t.samples, t.names);
  if (bank.words !== t.words) throw new Error(`E12: the bank takes ${bank.words} DSP2 words laid out, ${t.words} planned`);
  const P = planX20(R, t, packs, { ...opt, link: true });
  if (P.problems.length) throw new Error(P.problems.join('\n'));
  const { sel, notes, dsp2: { regions, placed } } = P;
  const D = R.dsp2;

  // ---- 3. DSP2 payload: code before DSP2 starts, dispatch words after
  const neighbour = x20NeighbourReads(placed, notes);
  if (neighbour.length) notes.push(`the previous track's output read for X.20's four rotating buffers in ${neighbour.join(', ')}`);
  const mem = new Map<number, number>();
  const dispatchSpan = (t: { init: number; trigger: number; render: number }, k: 'init' | 'trigger' | 'render', a: number): boolean =>
    a > t[k] && a <= t[k] + D.dispatch.entries;
  for (const [a, ws] of placed.records) ws.forEach((w, k) => mem.set(a + k, w));
  const x20Own = new Set(R.file.ids.x20_own ?? []);
  for (const [a, w] of [...mem]) {
    for (const k of ['init', 'trigger', 'render'] as const) {
      if (!dispatchSpan(D.dispatch, k, a)) continue;
      const id = a - D.dispatch[k] - 1;
      mem.set(D.relocated[k] + (a - D.dispatch[k]), w);
      // X.20's own machines (its stock tables hold other code for them): the relocated tables only --
      // writing their stock-table entries hangs DSP2 at boot
      if (x20Own.has(id)) mem.delete(a);
    }
  }
  mem.set(D.usrBankEnd, bankEnd);                       // the user machines' SAMPLE_INFO: where the INTERNAL bank ends
  const inRegions = (a: number): boolean => regions.some(([lo, hi]) => a >= lo && a < hi);
  for (const a of mem.keys()) {
    const ok = inRegions(a) || a === D.usrBankEnd ||
      (['init', 'trigger', 'render'] as const).some((k) => dispatchSpan(D.dispatch, k, a) || (a > D.relocated[k] && a <= D.relocated[k] + D.relocated.entries));
    if (!ok) throw new Error(`DSP2 write at ${h(a)} outside the machines' regions and the dispatch tables`);
  }
  const all = blocks(mem);
  const boot = dsp2BootLoader(R);
  for (const [which, words, ops] of [['receiver', boot.receiver, boot.opcodes.receiver], ['wiper', boot.wiper.words, boot.opcodes.wiper]] as const) {
    const bad = cacheOpsIn([...words], ops);
    gates.push({ name: `DSP boot code (${which}): no cache instruction`, ok: !bad.length, detail: bad.length ? `cache instruction at word ${bad.join(', ')}` : `${words.length} words` });
    if (bad.length) throw new Error(`DSP boot code (${which}) holds a cache instruction: it traps on hardware with the cache off`);
  }
  const upload = opt.dsp2Load === 'upload';
  if (upload) notes.push('DSP2 load: upload after DSP2 starts (emulator only; not for hardware)');
  const pre: [number, number[]][] = upload ? [] : [[boot.wiper.addr, boot.wiper.words], ...all.filter(([a]) => inRegions(a))];
  // dispatch words last: an entry must never point at code that is not in DSP2 yet (the P-I clean stub
  // the stock P-I inits are redirected to lives in the second region, above the dispatch tables)
  const post = (upload ? all : all.filter(([a]) => !inRegions(a))).sort(([x], [y]) => Number(!inRegions(x) && x !== D.usrBankEnd) - Number(!inRegions(y) && y !== D.usrBankEnd) || x - y);
  for (const [a, ws] of pre) if (a < boot.wiper.addr + boot.wiper.words.length && boot.wiper.addr < a + ws.length && a !== boot.wiper.addr)
    throw new Error('a machine overlaps the boot loader\'s wiper');

  // ---- flash: chunks, then our list entries, in the flash the bank frees
  const spans = freeFlash(bank).map(([a, b]) => [a, b] as [number, number]);
  const rawMax = Math.min(RAW_MAX_DEFAULT, R.ram.uploadBuffer[1] - R.ram.uploadBuffer[0]);
  const flashCapacity = spans.reduce((n, [a, b]) => n + b - a, 0);
  const preC = await chunks(pre, spans, rawMax, flashCapacity);
  const postC = await chunks(post, spans, rawMax, flashCapacity);
  const list = concat(sel.map(listEntry));
  const li = spans.findIndex(([a, b]) => b - ((a + 3) & ~3) >= list.length);
  if (li < 0) throw new X20FlashError(flashCapacity + list.length, flashCapacity, 'no flash left for the new-machine list: trim harder or untick a machine');
  const listFlash = (spans[li][0] + 3) & ~3;
  spans[li] = [listFlash + list.length, spans[li][1]];
  // the layout table (md-layout/1, the same table the 1.63-lineage bases carry), after the list: a later
  // build restores IDs and families from this .syx
  const table = encodeLayout(P.table);
  const ti = spans.findIndex(([a, b]) => b - ((a + 3) & ~3) >= table.length);
  if (ti < 0) throw new X20FlashError(flashCapacity + table.length, flashCapacity, 'no flash left for the layout table: trim harder or untick a machine');
  const tableFlash = (spans[ti][0] + 3) & ~3;
  spans[ti] = [tableFlash + table.length, spans[ti][1]];
  // the bank (free flash erased), then the chunks and the list in its free flash
  cont.set(bank.area.subarray(0, E12B_END - E12B_FLASH), areaOff);
  for (const c of [...preC, ...postC]) cont.set(c.packed, at(c.at));
  cont.set(list, at(listFlash));
  cont.set(table, at(tableFlash));

  // ---- 4. ColdFire: window A, the OS writes, the stage code
  const M = x20Map(R, sel.length, bankEnd);
  const ours = new Map(sel.map((s) => [s.id, menuFamily(R, s, opt.layout)] as [number, number]));
  const wa = windowA(R, M, ours, fromBase64(core.knob_callback), listFlash);
  if (wa.asm.bytes.length + R.ram.window[0] > R.ram.window[1]) throw new Error('window A overflows');
  const names: Record<string, number> = { STACK: M.stack, RECS: M.recs, CAP: M.cap, MENU: M.menu, M_U: M.mU, M_L: M.mL,
    LIST: M.list, LIST_N: M.listN, BANK_END: bankEnd, HTAB: wa.htab };
  const writes: [number, Uint8Array][] = [];
  const siteCode: { at: number; bytes: Uint8Array }[] = [];
  for (const s of R.sites) {
    const b = siteBytes(s.value, names, wa.asm.labels);
    if (b.length !== s.old.length) throw new Error(`recipe site ${h(s.at)} (${s.what}): ${b.length} bytes for a ${s.old.length}-byte anchor`);
    writes.push([s.at, b]);
    if (isCode(s.value)) siteCode.push({ at: s.at, bytes: b });
  }
  const st = stageCode(R, writeList(writes), preC.map((c) => R.flashAlias + c.at), postC.map((c) => R.flashAlias + c.at), wa, boot.receiver);

  // ---- gate: ISA_A over everything the ColdFire runs that the build adds
  const entries = [st.asm.labels.APPLIER, st.asm.labels.DSP2PRE, ...['VALID', 'FAM', 'CLS', 'GUARD', 'ERGUARD', 'COPYLIST', 'USRCHKREC', 'USRINSMENU', 'USRREM'].map((n) => wa.asm.labels[n]), wa.knobcb];
  const codeMem: CodeMem[] = [{ what: 'boot code', ram: R.ram.bootCode[0], bytes: st.asm.bytes }, { what: 'window A', ram: R.ram.window[0], bytes: wa.asm.bytes }];
  const inOurs = (a: number): boolean => codeMem.some((m) => a >= m.ram && a < m.ram + m.bytes.length);
  const isa = x20IsaGate(codeMem, entries, inOurs, [...siteCode, ...st.sites.map((s) => ({ at: s.at, bytes: s.bytes }))]);
  gates.push({ name: 'ISA_A (MCF5206e): routines, OS sites and loader sites', ok: !isa.rejects.length,
    detail: `${isa.insns} instructions${isa.rejects.length ? '; ' + isa.rejects.map((i) => `${h(i.at)} ${i.name}: ${i.why}`).join('; ') : ''}` });
  if (isa.rejects.length) throw new Error(`ISA_A gate: ${isa.rejects.map((i) => `${h(i.at)} ${i.name}: ${i.why}`).join('; ')}`);

  // ---- 5. stage image and slot 0
  const L = R.loader;
  const n0 = u32(cont, 0);
  const slot = cont.slice(8, 8 + n0);
  const s0 = nrv2bDecode(slot).out;
  if (await sha256(s0) !== R.file.identify.stage_sha256) throw new Error(`${R.name}: the loader's stage image is not the one the recipe knows`);
  if (s0.length !== L.header + L.stage2Bytes) throw new Error('stage image length');
  if (u32(s0, L.copyLongsAt) !== L.copyLongs) throw new Error('stage 1 copy count');
  const off = (ram: number): number => L.header + ram - L.stage2;
  const img = new Uint8Array(off(R.ram.window[0]) + wa.asm.bytes.length + 16);
  img.set(s0);
  for (const s of st.sites) {
    const o = off(s.at), old = Array.from(img.subarray(o, o + s.bytes.length), (b) => b.toString(16).padStart(2, '0')).join('');
    if (old !== s.old) throw new Error(`loader site ${h(s.at)} (${s.what}): ${old}, expected ${s.old}`);
    img.set(s.bytes, o);
  }
  img.set(st.asm.bytes, off(R.ram.bootCode[0]));
  img.set(wa.asm.bytes, off(R.ram.window[0]));
  let len = off(R.ram.window[0]) + wa.asm.bytes.length;
  while ((len - L.header) % 16) len++;
  const stage = img.slice(0, len);
  stage.set(be32((len - L.header) / 4), L.copyLongsAt);
  const packed = await uclPack(stage, Number((globalThis as { process?: { env: Record<string, string | undefined> } }).process?.env.KB_STAGE_LEVEL ?? 10));
  const back = nrv2bDecode(packed).out;
  if (back.length !== stage.length || back.some((b, k) => b !== stage[k])) throw new Error('stage image NRV2B round trip');
  const room = L.payloadFlash - L.slot0Flash;
  if (packed.length > room) throw new Error(`the re-packed stage image is ${packed.length} bytes, ${room} fit before the loader's payload`);
  const newSlot = concat([packed, new Uint8Array(room - packed.length).fill(0xff), slot.subarray(room)]);
  cont.set(be32(n0), 0);
  cont.set(be32(sum32(newSlot)), 4);
  cont.set(newSlot, 8);
  const output = encodeSyx(cont);
  if (decodeSyx(output).some((b, k) => b !== cont[k])) throw new Error('.syx round trip');

  const used = [...preC, ...postC].reduce((n, c) => n + c.packed.length, 0) + list.length;
  const report: X20Report = {
    base: R.id,
    machines: placed.machines.map((m) => ({ name: m.name.trim(), key: m.key, id: m.id, family: m.family, org: h(m.org), words: m.total })),
    e12: { bank_end: h(bankEnd), words: bank.words, stock_words: stockWords, freed_words: R.e12.bankEnd - bankEnd,
      flash_end: h(E12B_FLASH + (bank.used - 1) * 0x10000 + bank.end), trimmed: nTrim,
      ...(t.edits ? { edits: { swapped: [...t.edits.swaps.keys()].sort((a, b) => a - b), capped: t.capped, no_trim: [...t.edits.noTrim].sort((a, b) => a - b) } } : {}) },
    dsp2: { capacity: placed.capacity, demand: placed.demand, free: placed.free, regions: regions.map(([a, b]) => [h(a), h(b)] as [string, string]) },
    flash: { chunks_pre: preC.map((c) => [h(c.at), c.packed.length]), chunks_post: postC.map((c) => [h(c.at), c.packed.length]), list: h(listFlash),
      free_left: spans.reduce((n, [a, b]) => n + Math.max(0, b - a), 0),
      capacity: flashCapacity, used: used + table.length, layout: h(tableFlash) },
    layout: P.table,
    menus: P.menus.map((f) => ({ name: f.name, machines: f.models.map((m) => m.name.trim()) })),
    moves: P.moves,
    stage: { boot_code: `${h(R.ram.bootCode[0])}..${h(R.ram.bootCode[0] + st.asm.bytes.length)}`, window: `${h(R.ram.window[0])}..${h(R.ram.window[0] + wa.asm.bytes.length)}`,
      packed: packed.length, room },
    gates, notes: [...notes, `${used} bytes of E12B flash used for the machines`],
  };
  return { output, report };
}
