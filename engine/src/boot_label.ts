import { Asm } from './cf_asm.js';

export interface BootLabel { text: string; id: string; sha256: string; scheme: 'kb-build/1'; uw: boolean }
export function bootLabel(uw: boolean, sha256: string): BootLabel {
  if (!/^[0-9a-f]{64}$/.test(sha256)) throw new Error('Invalid build fingerprint');
  const id = sha256.slice(0, 6).toUpperCase();
  return { text: `${uw ? 'UW' : 'NON-UW'} ${id}`, id, sha256, scheme: 'kb-build/1', uw };
}

// Original 5x7 glyphs, one column per byte, top pixel in bit zero. Padding makes an
// eight-column cell, matching the boot display's serial eight-byte write protocol.
const FONT: Record<string, number[]> = {
  ' ': [0,0,0,0,0], '-': [8,8,8,8,8],
  '0': [62,65,65,65,62], '1': [0,66,127,64,0], '2': [98,81,73,73,70],
  '3': [34,65,73,73,54], '4': [24,20,18,127,16], '5': [39,69,69,69,57],
  '6': [62,73,73,73,50], '7': [1,113,9,5,3], '8': [54,73,73,73,54], '9': [38,73,73,73,62],
  A: [126,9,9,9,126], B: [127,73,73,73,54], C: [62,65,65,65,34],
  D: [127,65,65,34,28], E: [127,73,73,73,65], F: [127,9,9,9,1],
  N: [127,2,4,8,127], O: [62,65,65,65,62], U: [63,64,64,64,63], W: [63,64,56,64,63],
};

/** One centered row at y=48, clear of the logo and the y=56 version row. */
export function bootLabelStream(text: string): Uint8Array {
  if (!text.length || text.length > 16 || [...text].some(c => !FONT[c])) throw new Error('Boot label does not fit');
  const bytes: number[] = [];
  const start = Math.floor((16 - text.length) / 2) * 8;
  for (let i = 0; i < text.length; i++) {
    const x = start + i * 8;
    bytes.push(x < 64 ? 0x16 : 0x1e, x & 63, 0, ...FONT[text[i]], 0, 0);
  }
  return Uint8Array.from(bytes);
}

/** Runs once after X.20 relocates its loader, before DSP/OS loading. The boot
 * block has initialized the panel UART. Never calls or modifies boot-block code.
 * A bounded wait makes an unavailable display skip the label rather than hang boot. */
export function appendBootLabel(s: Asm, label: BootLabel, resume: number): void {
  const stream = bootLabelStream(label.text);
  const S = (op: string, ...args: string[]): void => s.i(op, ...args);
  s.align(4);
  s.label('BOOT_LABEL');
  S('lea', '-20(a7)', 'a7'); S('movem.l', 'd0-d2/a0-a1', '(a7)');
  S('lea', '@boot_label_stream', 'a0'); S('move.l', `#${stream.length}`, 'd2');
  s.label('bl_byte');
  S('move.l', '#0x10000', 'd1');
  s.label('bl_wait');
  S('move.b', '0x300184.l', 'd0'); S('btst', '#3', 'd0'); S('bne.b', 'bl_ready');
  S('subq.l', '#1', 'd1'); S('bne.b', 'bl_wait'); S('bra.b', 'bl_done');
  s.label('bl_ready');
  S('move.b', '(a0)+', 'd0'); S('move.b', 'd0', '0x30018c.l');
  S('subq.l', '#1', 'd2'); S('bne.b', 'bl_byte');
  S('move.l', '#0x10000', 'd1');
  s.label('bl_drain');
  S('move.b', '0x300184.l', 'd0'); S('btst', '#3', 'd0'); S('bne.b', 'bl_done');
  S('subq.l', '#1', 'd1'); S('bne.b', 'bl_drain');
  s.label('bl_done');
  S('movem.l', '(a7)', 'd0-d2/a0-a1'); S('lea', '20(a7)', 'a7'); S('jmp', `0x${resume.toString(16)}.l`);
  s.bytes('boot_label_stream', stream);
  s.bytes('boot_label_identity', new TextEncoder().encode(`KBID1:${label.uw ? 'UW' : 'NU'}:${label.sha256}\0`));
  s.align(4);
}
