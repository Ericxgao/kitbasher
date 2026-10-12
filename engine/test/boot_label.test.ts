import { test } from 'node:test';
import assert from 'node:assert/strict';
import { appendBootLabel, bootLabel, bootLabelStream } from '../src/boot_label.js';
import { Asm } from '../src/cf_asm.js';
import { decodeLinear } from '../src/isa.js';
import { Cpu } from './cf_interp.js';

test('compact labels identify the selected UW target and retain the full fingerprint', () => {
  const hash = 'a7c29f' + '0'.repeat(58);
  assert.equal(bootLabel(true, hash).text, 'UW A7C29F');
  assert.equal(bootLabel(false, hash).text, 'NON-UW A7C29F');
  assert.equal(bootLabel(true, hash).sha256, hash);
  assert.throws(() => bootLabel(true, 'short'), /fingerprint/);
  assert.throws(() => bootLabelStream('TOO LONG TO FIT THE SCREEN'), /fit/);
});

test('label writes stay on the empty row above the version, within the 128-pixel LCD', () => {
  for (const uw of [false, true]) {
    const text = bootLabel(uw, '0123456789abcdef'.repeat(4)).text;
    const bytes = bootLabelStream(text);
    const xs: number[] = [];
    assert.equal(bytes.length, text.length * 10);
    for (let at = 0; at < bytes.length; at += 10) {
      assert.ok(bytes[at] === 0x16 || bytes[at] === 0x1e);
      const x = bytes[at + 1] + (bytes[at] === 0x1e ? 64 : 0);
      assert.ok(x >= 0 && x + 8 <= 128);
      assert.ok(bytes.slice(at + 2, at + 10).every(b => b < 128));
      xs.push(x);
    }
    assert.ok(xs.every((x, i) => !i || x === xs[i - 1] + 8));
  }
});

test('emitted ColdFire preserves registers and stack, sends the exact panel stream, and times out safely', () => {
  const org = 0x2fb600, resume = 0x2f8000;
  const label = bootLabel(false, 'abcdef0123456789'.repeat(4));
  const s = new Asm(org); appendBootLabel(s, label, resume);
  const asm = s.assemble();
  assert.ok(decodeLinear(asm.bytes.subarray(0, asm.labels.boot_label_stream - org), org).every(i => i.ok && !i.mac));
  for (const ready of [true, false]) {
    const sent: number[] = [], writes: number[] = [];
    let reads = 0;
    class PanelCpu extends Cpu {
      override r8(at: number): number { return at === 0x300184 ? (++reads % 3 === 0 && ready ? 8 : 0) : super.r8(at); }
      override w8(at: number, value: number): void { writes.push(at); if (at === 0x30018c) sent.push(value & 255); else super.w8(at, value); }
    }
    const cpu = new PanelCpu(resume);
    cpu.load(org, asm.bytes);
    for (let i = 0; i < 8; i++) { cpu.d[i] = 0x12345678 + i; if (i < 7) cpu.a[i] = 0x87654321 + i; }
    const ds = cpu.d.slice(), as = cpu.a.slice();
    cpu.pc = asm.labels.BOOT_LABEL;
    for (let steps = 0; cpu.pc !== resume; steps++) { assert.ok(steps < 400_000, 'bounded UART wait'); cpu.step(); }
    assert.deepEqual(cpu.d, ds); assert.deepEqual(cpu.a, as);
    assert.deepEqual(Uint8Array.from(sent), ready ? bootLabelStream(label.text) : new Uint8Array());
    assert.ok(writes.every(at => at === 0x30018c || at >= resume - 20 && at < resume), 'only UART and the reserved stack frame may change');
    assert.equal(cpu.srWrites.length, 0);
  }
});
