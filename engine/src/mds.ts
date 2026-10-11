/** MDS v1 packages and wire framing. Independent of browser/MIDI I/O.
 * Specification: https://github.com/jmamma/MDS/tree/main/docs
 */
export const MDS_PREFIX = [0xf0, 0, 0x20, 0x3c, 2, 0, 0x74, 1];
export const CMD = { header: 1, data: 2, slots: 4, slotsReply: 5, caps: 6, capsReply: 7, end: 123, wait: 124, cancel: 125, nak: 126, ack: 127 } as const;
export function requireMds(ok: unknown, message: string): asserts ok { if (!ok) throw new Error(message); }
export const hex = (v: Uint8Array): string => Array.from(v, n => n.toString(16).padStart(2, '0')).join('');
export function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0)); let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; } return out;
}
export function crc32(data: Uint8Array): number {
  let c = 0xffffffff;
  for (const b of data) { c ^= b; for (let i = 0; i < 8; i++) c = (c >>> 1) ^ ((c & 1) ? 0xedb88320 : 0); }
  return (c ^ 0xffffffff) >>> 0;
}
const view = (b: Uint8Array) => new DataView(b.buffer, b.byteOffset, b.byteLength);
const ascii = (b: Uint8Array) => String.fromCharCode(...b).replace(/\0+$/, '').trim();
export interface MdsMessage { command: number; transaction: number; slot: number; sequence: number; body: Uint8Array }
export function encodeMessage(command: number, transaction: number, slot = 127, sequence = 127, body: Uint8Array = new Uint8Array()): Uint8Array {
  requireMds(Number.isInteger(transaction) && transaction >= 0 && transaction < 16384, 'Invalid transaction');
  requireMds([command, slot, sequence].every(n => Number.isInteger(n) && n >= 0 && n < 128) && body.length <= 420, 'Invalid MDS message');
  const packed: number[] = [];
  for (let i = 0; i < body.length; i += 7) {
    const group = body.slice(i, i + 7); packed.push(group.reduce((mask, n, j) => mask | ((n >> 7) << (6 - j)), 0));
    packed.push(...group.map(n => n & 127));
  }
  const checked = [transaction >> 7, transaction & 127, slot, sequence, 0, ...packed];
  const crc = checked.reduce((n, b) => n + b, 0) & 16383, length = checked.length + 4;
  return Uint8Array.from([...MDS_PREFIX, command, ...checked, crc >> 7, crc & 127, length >> 7, length & 127, 247]);
}
export function decodeMessage(input: Uint8Array): MdsMessage {
  const b = input.filter(v => v < 248); // MIDI realtime is allowed between SysEx bytes.
  requireMds(b.length >= 19 && b.length <= 499 && MDS_PREFIX.every((n, i) => b[i] === n) && b.at(-1) === 247, 'Not an MDS v1 message');
  requireMds(b.slice(1, -1).every(n => n < 128) && b[13] === 0, 'Invalid MIDI byte or flags');
  requireMds((b.at(-3)! * 128 + b.at(-2)!) === b.length - 10, 'MDS wire length mismatch');
  requireMds((b.at(-5)! * 128 + b.at(-4)!) === (b.slice(9, -5).reduce((n, v) => n + v, 0) & 16383), 'MDS wire checksum mismatch');
  const packed = b.slice(14, -5), body: number[] = [];
  for (let i = 0; i < packed.length; i += 8) {
    const g = packed.slice(i, i + 8);
    requireMds(g.length > 1 && !(g[0] & ((1 << (8 - g.length)) - 1)), 'Invalid seven-bit packing');
    for (let j = 1; j < g.length; j++) body.push(g[j] | (((g[0] >> (7 - j)) & 1) << 7));
  }
  return { command: b[8], transaction: b[9] * 128 + b[10], slot: b[11], sequence: b[12], body: Uint8Array.from(body) };
}
export interface MdsParameter { name: string; default: number; min: number; max: number; style: number }
export interface MdsMachine {
  bytes: Uint8Array; id: string; name: string; alias: string; category: string; code: string;
  version: string; words: number; cycles: number; contentId: string; requiredFeatures: number;
  tonal: boolean; neighbour: boolean; stereoPair: boolean;
  parameters: MdsParameter[];
}
/** Validate hashes and resource/layout metadata before displaying or transmitting a package.
 * The device remains responsible for DSP code/ABI admission; hashes are not a safety review.
 */
export async function parsePackage(input: Uint8Array): Promise<MdsMachine> {
  const b = new Uint8Array(input), d = view(b);
  requireMds(b.length >= 384 && b.length <= 420 * 127 && b.length % 4 === 0 && ascii(b.slice(0, 4)) === 'MDS1', 'Invalid MDS package');
  requireMds(d.getUint16(4) === 1 && d.getUint16(6) === 128 && d.getUint32(8) === b.length, 'Unsupported MDS version or size');
  requireMds(d.getUint32(12) === 0 && d.getUint16(16) === 0x5603 && d.getUint16(18) === 1 && b[20] === 0 && b[21] === 0, 'Unsupported target or codec');
  requireMds([54, 55, 60, 61, 62, 63, 72, 73, 74, 75, 120, 121, 122, 123, 124, 125, 126, 127].every(i => b[i] === 0), 'Nonzero reserved field');
  const words = d.getUint16(22), imports = d.getUint16(24), cycles = d.getUint16(70), size = words * 3;
  requireMds(words > 0 && imports <= 64 && d.getUint16(26) <= 64 && d.getUint16(28) <= 64 && cycles > 0, 'Invalid resources or unfinished cycle declaration');
  requireMds([64, 66, 68].every(i => d.getUint16(i) < words), 'Invalid routine entry');
  requireMds(d.getUint32(32) === 128 && d.getUint32(36) === size && d.getUint32(40) === size, 'Invalid program layout');
  const align = (n: number) => Math.ceil(n / 4) * 4;
  const rel = align(128 + size), imp = align(rel + Math.ceil(words / 8)), desc = align(imp + imports * 4), descSize = d.getUint16(52);
  requireMds(d.getUint32(44) === rel && d.getUint32(48) === imp && d.getUint32(56) === desc && descSize >= 128 && descSize <= 384 && (descSize - 128) % 8 === 0 && desc + descSize + 128 === b.length, 'Invalid section layout');
  for (const [from, to] of [[128 + size, rel], [rel + Math.ceil(words / 8), imp]]) requireMds(b.slice(from, to).every(n => n === 0), 'Nonzero alignment padding');
  requireMds(ascii(b.slice(desc, desc + 4)) === 'MDM1' && b[desc + 4] === 1 && b[desc + 5] <= 8 && !(b[desc + 6] & ~29) && b[desc + 14] === 0 && b[desc + 15] !== 255, 'Invalid machine description');
  requireMds(crc32(b.slice(128, 128 + size)) === d.getUint32(76) && crc32(b.slice(desc, desc + descSize)) === d.getUint32(80), 'Program or description CRC mismatch');
  const check = b.slice(); check.fill(0, 84, 88);
  requireMds(crc32(check) === d.getUint32(84), 'Package CRC mismatch'); check.fill(0, 88, 120);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', concat([check, b.slice(128, 128 + size)]) as Uint8Array<ArrayBuffer>));
  requireMds(hex(digest) === hex(b.slice(88, 120)), 'Package content ID mismatch');
  let requiredFeatures = b[desc + 15] ? 4 : 0, previous = -1;
  for (let i = 0; i < imports; i++) {
    const at = imp + i * 4, word = d.getUint16(at), kind = b[at + 2], symbol = b[at + 3];
    requireMds(word > previous && word < words && !(b[rel + (word >> 3)] & (1 << (word & 7))), 'Invalid import location'); previous = word;
    requireMds((kind === 1 && symbol >= 1 && symbol <= 5) || (kind === 2 && symbol === 6) || (kind === 3 && symbol === 7) || (kind === 4 && symbol === 8) || (kind === 5 && symbol >= 9 && symbol <= 12), 'Unsupported import');
    if (symbol === 9 || symbol === 10) requiredFeatures |= 1;
    if (symbol === 11 || symbol === 12) requiredFeatures |= 2;
  }
  const category = ascii(b.slice(desc + 8, desc + 12)), code = ascii(b.slice(desc + 12, desc + 14));
  requireMds(/^([A-Z0-9]{1,3}|P-I)$/.test(category) && !['MID', 'CTR', 'CTL'].includes(category) && /^[A-Z0-9]{2}$/.test(code), 'Invalid machine name');
  const parameters: MdsParameter[] = [];
  for (let i = 0; i < b[desc + 5]; i++) {
    const at = desc + 64 + i * 8;
    const p = { name: ascii(b.slice(at, at + 4)), default: b[at + 4], min: b[at + 5], max: b[at + 6], style: b[at + 7] };
    requireMds(p.min < p.max && p.max <= 127 && p.default >= p.min && p.default <= p.max && [0, 16, 32, 1, 33, 2, 34, 19, 84, 53, 70, 7].includes(p.style), 'Invalid parameter'); parameters.push(p);
  }
  return { bytes: b, id: ascii(b.slice(desc + 32, desc + 64)), name: ascii(b.slice(desc + 16, desc + 32)), alias: `${category}-${code}`, category, code, version: `${b[30]}.${b[31]}`, words, cycles, contentId: hex(digest), requiredFeatures, tonal: !!(b[desc + 6] & 1), neighbour: !!(b[desc + 6] & 8), stereoPair: !!(b[desc + 6] & 16), parameters };
}
export function machineMessages(machine: MdsMachine, slot: number, transaction: number): Uint8Array[] {
  requireMds(Number.isInteger(slot) && slot >= 0 && slot < 16, 'Choose U01–U16');
  const b = machine.bytes, count = Math.ceil(b.length / 420), header = new Uint8Array(42), d = view(header);
  d.setUint32(0, b.length); header[4] = count; header.set(b.slice(84, 120), 6);
  const packets = [encodeMessage(CMD.header, transaction, slot, 127, header)];
  for (let i = 0; i < count; i++) packets.push(encodeMessage(CMD.data, transaction, slot, i, b.slice(i * 420, (i + 1) * 420)));
  packets.push(encodeMessage(CMD.end, transaction, slot, count)); return packets;
}
export async function parseSysex(file: Uint8Array): Promise<MdsMachine[]> {
  requireMds(file.length <= 2_000_000, 'Machine file is too large');
  const messages: MdsMessage[] = []; let pending: number[] = [];
  for (const b of file) {
    if (b >= 248) continue;
    if (b === 240) { requireMds(!pending.length, 'Nested SysEx message'); pending = [b]; }
    else { requireMds(pending.length > 0, 'Unexpected bytes outside MDS message'); pending.push(b); }
    requireMds(pending.length <= 499, 'MDS message too large');
    if (b === 247) { messages.push(decodeMessage(Uint8Array.from(pending))); pending = []; }
  }
  requireMds(!pending.length && messages.length > 0, 'Incomplete or empty SysEx file');
  const result: MdsMachine[] = [];
  for (let i = 0; i < messages.length;) {
    const h = messages[i++], d = view(h.body);
    requireMds(h.command === CMD.header && h.sequence === 127 && h.slot < 16 && h.body.length === 42 && h.body[5] === 0, 'Expected MDS dump header');
    const count = h.body[4], size = d.getUint32(0), parts: Uint8Array[] = [];
    requireMds(count > 0 && count === Math.ceil(size / 420), 'Invalid packet count');
    for (let n = 0; n < count; n++) {
      const p = messages[i++]; requireMds(p && p.command === CMD.data && p.transaction === h.transaction && p.slot === h.slot && p.sequence === n && p.body.length === Math.min(420, size - n * 420), 'Missing, reordered or mismatched data packet'); parts.push(p.body);
    }
    const end = messages[i++]; requireMds(end && end.command === CMD.end && end.transaction === h.transaction && end.slot === h.slot && end.sequence === count && !end.body.length, 'Missing end of dump');
    const m = await parsePackage(concat(parts)); requireMds(hex(h.body.slice(6)) === hex(m.bytes.slice(84, 120)), 'Transfer descriptor mismatch'); result.push(m);
  }
  return result;
}
export interface MdsCaps { maxPackage: number; maxWords: number; maxPacket: number; totalWords: number; freeWords: number; totalBytes: number; freeBytes: number; slots: number; features: number; trackLimit: number }
export interface MdsSlot { slot: number; flags: number; model: number; words: number; bytes: number; alias: string; contentId: string }
export interface MdsSnapshot { generation: number; slots: MdsSlot[]; caps: MdsCaps }
export const X20_CAPS: MdsCaps = { maxPackage: 53340, maxWords: 14052, maxPacket: 499, totalWords: 14052, freeWords: 14052, totalBytes: 59480, freeBytes: 59480, slots: 16, features: 7, trackLimit: 3951 };
export function parseCaps(b: Uint8Array): MdsCaps {
  requireMds(b.length === 38, 'Invalid capability reply'); const d = view(b);
  requireMds(b[14] === 16 && b[17] === 1 && (d.getUint16(18) & 1), 'Unsupported MDS library or codec');
  const c = { maxPackage: d.getUint16(0), maxWords: d.getUint16(2), maxPacket: d.getUint16(4), totalWords: d.getUint16(6), freeWords: d.getUint16(8), totalBytes: d.getUint16(10), freeBytes: d.getUint16(12), slots: b[14], features: d.getUint32(22), trackLimit: Math.floor(d.getUint32(34) / 16) };
  requireMds(c.maxPacket >= 499 && c.totalWords > 0 && c.totalBytes > 0 && c.trackLimit > 0 && c.freeWords <= c.totalWords && c.freeBytes <= c.totalBytes, 'Invalid or unsupported device capacities'); return c;
}
export function parseSlots(b: Uint8Array): { generation: number; slots: MdsSlot[] } {
  requireMds(b.length === 356, 'Invalid slot list'); const d = view(b);
  return { generation: d.getUint32(0), slots: Array.from({ length: 16 }, (_, slot) => {
    const at = 4 + slot * 22; return { slot, flags: b[at], model: b[at + 1], words: d.getUint16(at + 2), bytes: d.getUint16(at + 4), alias: ascii(b.slice(at + 6, at + 14)), contentId: hex(b.slice(at + 14, at + 22)) };
  }) };
}
export interface MdsAssignment { slot: number; machine: MdsMachine }
export function planBank(assignments: MdsAssignment[], snapshot?: MdsSnapshot) {
  const caps = snapshot?.caps ?? X20_CAPS, slots = snapshot?.slots ?? [], problems: string[] = [];
  let words = caps.totalWords - caps.freeWords, bytes = caps.totalBytes - caps.freeBytes;
  const seen = new Set<number>(), changes: (MdsAssignment & { previous?: MdsSlot; wordDelta: number; byteDelta: number })[] = [];
  for (const a of assignments) {
    const m = a.machine, old = slots[a.slot], present = !!(old?.flags & 1);
    if (!Number.isInteger(a.slot) || a.slot < 0 || a.slot >= caps.slots || seen.has(a.slot)) { problems.push('Each machine needs a distinct slot from U01 to U16.'); continue; } seen.add(a.slot);
    if (m.bytes.length > caps.maxPackage || m.words > caps.maxWords || m.cycles > caps.trackLimit || !m.cycles) problems.push(`${m.alias} exceeds this device’s package or CPU limit.`);
    if ((m.requiredFeatures & caps.features) !== m.requiredFeatures) problems.push(`${m.alias} needs services this firmware does not report.`);
    const wordDelta = m.words - (present ? old.words : 0), byteDelta = m.bytes.length - (present ? old.bytes : 0);
    words += wordDelta; bytes += byteDelta;
    if (present && old.contentId === m.contentId.slice(0, 16) && (old.flags & 21) === 5) continue;
    if (old?.flags & 8) problems.push(`U${String(a.slot + 1).padStart(2, '0')} is in use. Unassign it from tracks before replacing it.`);
    changes.push({ ...a, previous: present ? old : undefined, wordDelta, byteDelta });
  }
  if (words > caps.totalWords) problems.push(`Remove ${words - caps.totalWords} DSP words from the selection.`);
  if (bytes > caps.totalBytes) problems.push(`Remove ${bytes - caps.totalBytes} package bytes from the selection.`);
  // An install commits one machine at a time. Final fit alone does not guarantee intermediate fit.
  const visited = new Set<number>();
  function order(mask: number, usedWords: number, usedBytes: number): number[] | undefined {
    if (mask === (1 << changes.length) - 1) return [];
    if (visited.has(mask)) return undefined; visited.add(mask);
    for (let i = 0; i < changes.length; i++) if (!(mask & (1 << i))) {
      const a = changes[i], w = usedWords + a.wordDelta, b = usedBytes + a.byteDelta;
      if (w > caps.totalWords || b > caps.totalBytes) continue;
      const rest = order(mask | (1 << i), w, b); if (rest) return [i, ...rest];
    }
    return undefined;
  }
  const sequence = problems.length ? [] : order(0, caps.totalWords - caps.freeWords, caps.totalBytes - caps.freeBytes);
  if (!sequence) problems.push('The final bank fits only after freeing space on the device. No safe replacement order fits the current library.');
  const ordered = (sequence ?? []).map(i => changes[i]);
  return { caps, words, bytes, changes: ordered, problems: [...new Set(problems)], occupied: slots.filter(s => (s.flags & 1) && !seen.has(s.slot)).length + seen.size };
}
