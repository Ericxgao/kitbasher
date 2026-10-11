// Offline checks of an X.20 recipe against a decoded X.20 OS image (the ColdFire image the loader
// rebuilds at boot; never shipped, never read by the build). Run by engine/test/x20.test.ts when
// KB_X20_OS names such an image.
//
//  - anchors: every site holds the bytes the recipe says it holds;
//  - relocation audit: every instruction that can reach what the recipe moves or resizes -- the
//    old record table, menu struct and new-machine list, the stack region and the RAM above the heap,
//    the record cap, and the fields of the globals block the USR routines reach base-relative --
//    is one the recipe patches or one its audit allowlist explains. A table the recipe moves but some
//    code still reaches by an address or offset nobody patched is how the first X.20 build broke USR
//    machine installs (RECV FAIL): those routines reached the records as $800(base) with a cap of 159.

import { decode } from './isa.js';
import type { X20Recipe } from './x20_recipe.js';

export const OS_BASE = 0x200000;

export function anchorMismatches(R: X20Recipe, os: Uint8Array): string[] {
  const out: string[] = [];
  const feats = Object.entries(R.features).flatMap(([name, F]) => [...F!.sites, ...F!.anchors.map((x) => ({ ...x, what: `${name}: ${x.what}` }))]);
  for (const s of [...R.sites, ...feats]) {
    const o = s.at - OS_BASE;
    const got = os.subarray(o, o + s.old.length);
    if (got.length !== s.old.length || got.some((b, k) => b !== s.old[k]))
      out.push(`${s.at.toString(16)} (${s.what}): ${Buffer.from(got).toString('hex')}, recipe ${Buffer.from(s.old).toString('hex')}`);
  }
  return out;
}

export interface AuditSpec {
  code_end: string;
  /** [lo, hi) address ranges whose 32-bit references count */
  regions: { what: string; lo: string; hi: string }[];
  /** 16-bit displacements off the globals base that reach moved fields */
  displacements: string[];
  /** long immediates that are the record cap */
  constants: string[];
  /** instruction (start) address -> why it needs no patch */
  allow: Record<string, string>;
}

/** Instruction starts by a linear sweep (an unknown word counts as a 2-byte instruction). */
function starts(os: Uint8Array, end: number): number[] {
  const out: number[] = [];
  for (let a = OS_BASE; a < end;) {
    out.push(a);
    let len = 2;
    try { len = Math.max(2, decode(os, a - OS_BASE, a).len); } catch { len = 2; }
    a += len;
  }
  return out;
}

export function relocationAudit(R: X20Recipe, os: Uint8Array, spec: AuditSpec): { checked: number; unexplained: string[] } {
  const end = parseInt(spec.code_end, 16);
  const st = starts(os, end);
  const lenAt = new Map<number, number>();
  st.forEach((a, k) => lenAt.set(a, (st[k + 1] ?? end) - a));
  const insnOf = (a: number): number => {   // the instruction containing byte a
    let lo = 0, hi = st.length - 1;
    while (lo < hi) { const m = (lo + hi + 1) >> 1; if (st[m] <= a) lo = m; else hi = m - 1; }
    return st[lo];
  };
  const patched = new Set<number>();
  for (const s of R.sites) for (let k = 0; k < s.old.length; k++) patched.add(s.at + k);
  const allow = new Set(Object.keys(spec.allow).map((k) => parseInt(k, 16)));
  const regions = spec.regions.map((r) => ({ what: r.what, lo: parseInt(r.lo, 16), hi: parseInt(r.hi, 16) }));
  const disps = new Set(spec.displacements.map((d) => parseInt(d, 16)));
  const consts = new Set(spec.constants.map((d) => parseInt(d, 16)));
  const seen = new Set<number>();
  const unexplained: string[] = [];
  /** whether the word at `a` is a (d16,An) displacement: the source operand's (right after the opcode),
   *  or a MOVE's destination's (its last word); immediates and absolute addresses are not */
  const isD16 = (a: number): boolean => {
    const s = insnOf(a), n = lenAt.get(s) ?? 2;
    if (s === a) return false;
    const op = (os[s - OS_BASE] << 8) | os[s - OS_BASE + 1];
    const src = (op >> 3) & 7, move = (op >> 12) >= 1 && (op >> 12) <= 3, dst = (op >> 6) & 7;
    if (a === s + 2 && src === 5) return true;
    return move && dst === 5 && a === s + n - 2;
  };
  const hit = (kind: string, at: number): void => {
    const s = insnOf(at);
    if (seen.has(s)) return;
    seen.add(s);
    const n = lenAt.get(s) ?? 2;
    for (let k = 0; k < n; k++) if (patched.has(s + k)) return;
    if (allow.has(s)) return;
    unexplained.push(`${kind} ${s.toString(16)} ${Buffer.from(os.subarray(s - OS_BASE, s - OS_BASE + n)).toString('hex')}`);
  };
  for (let o = 0; o + 4 <= end - OS_BASE; o += 2) {
    const v = ((os[o] << 24) | (os[o + 1] << 16) | (os[o + 2] << 8) | os[o + 3]) >>> 0;
    for (const r of regions) if (v >= r.lo && v < r.hi) hit(r.what, OS_BASE + o);
    if (consts.has(v) && o >= 2) {
      // a long immediate: the word before it opens a cmpi.l/move.l #imm form (or it is an extension of one)
      const s = insnOf(OS_BASE + o);
      if (s < OS_BASE + o) hit('cap constant', OS_BASE + o);
    }
    const w = (os[o] << 8) | os[o + 1];
    // any operand word for the field offsets (an addi #$19a8 to the base counts too); for $800, a value
    // common in other structs and immediates, only a (d16,An) displacement
    if (disps.has(w) && o >= 2 && insnOf(OS_BASE + o) < OS_BASE + o && (w !== 0x800 || isD16(OS_BASE + o))) hit('base displacement', OS_BASE + o);
  }
  return { checked: seen.size, unexplained };
}

/**
 * The pre-boot load, checked offline. The machines' code goes into DSP2 before DSP2's own loader runs,
 * so nothing that loader writes afterwards may land on it. `written` is the map of DSP2 external memory
 * X.20 B's own load writes (decoded offline from the release: [lo, hi] inclusive). Its E12 bank
 * ([table, stock bank end)) is rewritten at boot from the trimmed bank, which ends at `bankEnd`; every
 * other write it makes must miss the machines' regions and the boot loader (wiper and save area).
 */
export function preloadConflicts(R: X20Recipe, written: [number, number][], bankEnd: number, regions: [number, number][]): string[] {
  const out: string[] = [];
  const e12: [number, number] = [R.e12.table, R.e12.bankEnd];
  const B = R.dsp2.boot;
  const keep: [number, number, string][] = [...regions.map(([a, b]) => [a, b, 'machines'] as [number, number, string]),
    [B.wiper, B.saveEnd, 'boot loader wiper/save area']];
  if (bankEnd > e12[1] || bankEnd < e12[0]) out.push(`bank end ${bankEnd.toString(16)} outside the stock E12 bank`);
  for (const [lo, hiIncl] of written) {
    const hi = hiIncl + 1;
    // the parts of this write outside the E12 bank (the bank itself is rewritten from the trimmed one)
    const parts: [number, number][] = [];
    if (lo < e12[0]) parts.push([lo, Math.min(hi, e12[0])]);
    if (hi > e12[1]) parts.push([Math.max(lo, e12[1]), hi]);
    for (const [a, b] of parts) for (const [ka, kb, what] of keep)
      if (a < kb && ka < b) out.push(`X.20's load writes ${a.toString(16)}..${(b - 1).toString(16)}, over the ${what} at ${ka.toString(16)}..${(kb - 1).toString(16)}`);
  }
  // the trimmed bank's own writes end where the machines begin
  for (const [ka, kb, what] of keep) if (e12[0] < kb && ka < bankEnd) out.push(`the trimmed E12 bank (to ${bankEnd.toString(16)}) overlaps the ${what}`);
  return out;
}
