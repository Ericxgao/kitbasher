import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { FIRMWARE_VERSION, FIRMWARE_TAG, firmwareFilename, VERSION_WORDS, stampContainerVersion } from '../src/firmware_version.js';
import { parseRecipe, type X20RecipeFile } from '../src/x20_recipe.js';
import { isCode, siteBytes } from '../src/x20_cf.js';
import { buildX20, findX20Layout } from '../src/x20.js';
import { build } from '../src/build.js';
import { readFirmware } from '../src/container.js';
import { identify, NotPatchable } from '../src/bases.js';
import { loadBases, loadPacks } from '../src/node.js';
import { prepare163 } from '../src/prepare.js';
import { findLayout } from '../src/layout.js';
import { decodeSyx } from '../src/syx.js';
import { nrv2bDecode } from '../src/nrv2b.js';
import { sha256, u32, be32, concat } from '../src/bytes.js';

const ROOT = fileURLToPath(new URL('../../../', import.meta.url));
const recipe = (): X20RecipeFile => JSON.parse(readFileSync(join(ROOT, 'bases/x20.json'), 'utf8'));
const R = parseRecipe(recipe());
const ascii = (b: Uint8Array): string => new TextDecoder().decode(b).split('\0')[0];

test('firmware identity fits the legacy display and gives downloads a distinct name with base provenance', () => {
  assert.match(FIRMWARE_TAG, /^K\d\d $/);
  assert.equal(`${FIRMWARE_TAG[0]}.${FIRMWARE_TAG.slice(1).trim()}`, FIRMWARE_VERSION.display);
  assert.equal(firmwareFilename('x20'), 'kitbasher-K.01-x20.syx');
  assert.equal(firmwareFilename('x14'), 'kitbasher-K.01-x14.syx');
  assert.doesNotMatch(firmwareFilename('../bad/base'), /[/\\]/);
});

test('X.20 version sites replace both whole labels, preserve surrounding bytes, and remain data', () => {
  const labels = [[0x2ad7a8, 'X.20', 'K.01'], [0x2b223e, 'OS X.20 B', 'OS K.01']] as const;
  const sites = R.sites.filter(s => s.group === 'version');
  assert.equal(sites.length, 4);
  for (const [at, old, want] of labels) {
    const mem = Buffer.from(`!${old}\0!`);
    for (const s of sites.filter(s => s.at >= at && s.at < at + old.length + 1)) {
      const offset = s.at - at + 1;
      assert.deepEqual(new Uint8Array(mem.subarray(offset, offset + s.old.length)), s.old);
      assert.equal(isCode(s.value), false);
      const bytes = siteBytes(s.value, VERSION_WORDS, {});
      assert.equal(bytes.length, s.old.length);
      mem.set(bytes, offset);
    }
    assert.equal(ascii(mem.subarray(1)), want);
    assert.equal(mem[0], 33);
    assert.equal(mem[mem.length - 1], 33);
    assert.equal(mem[mem.length - 2], 0);
    assert.ok(mem.subarray(want.length + 1, -1).every(b => b === 0));
  }
});

test('startup container tag is changed separately, with bounds and source-tag guards', () => {
  // Unequal/odd slot sizes catch fixed-offset and alignment assumptions.
  const slots = [7, 15, 21].map(n => concat([be32(n), be32(123), new Uint8Array(n).fill(0xa5)]));
  const original = concat([...slots, new TextEncoder().encode('X20 '), new Uint8Array([9, 8, 7])]);
  const out = original.slice();
  const at = stampContainerVersion(out, 'X20 ');
  assert.equal(at, 67);
  assert.equal(ascii(out.subarray(at, at + 4)), 'K01 ');
  assert.deepEqual(out.subarray(0, at), original.subarray(0, at));
  assert.deepEqual(out.subarray(at + 4), original.subarray(at + 4));
  for (const size of [0, 4, 66, 68, 70]) {
    const short = original.slice(0, size), before = short.slice();
    assert.throws(() => stampContainerVersion(short, 'X20 '), /Firmware version/);
    assert.deepEqual(short, before, 'failure leaves the input unchanged');
  }
  const badLength = original.slice(); badLength.set(be32(0xffffffff), 0);
  assert.throws(() => stampContainerVersion(badLength, 'X20 '), /slot length/);
  assert.throws(() => stampContainerVersion(original.slice(), 'X14 '), /expected tag/);
});

// Optional real-input regression: no proprietary firmware in the repository.
const FW = process.env.MD_FIRMWARE_DIR;
test('firmware: versioned outputs keep source bytes and restorable layouts; emitted X.20 boot writes carry both labels',
  { skip: !FW || !existsSync(FW) ? 'MD_FIRMWARE_DIR is not set' : false }, async t => {
    const set = loadBases(join(ROOT, 'bases'));
    const { packs, core } = loadPacks(join(ROOT, 'catalog'));
    const selected = packs.map(p => ({ ...p, models: p.models.filter(m => m.key === 'VAD/BD') })).filter(p => p.models.length);
    assert.equal(selected.flatMap(p => p.models).length, 1);
    const opt = { uw: true, trim: { db: -30, minSeconds: 0.5, cap: 0.55 } };
    let count = 0;
    const seen = new Set<string>();
    for (const file of readdirSync(FW!).filter(f => /\.(syx|bin)$/i.test(f))) {
      let input: Uint8Array = readFileSync(join(FW!, file));
      const sourceHash = await sha256(input);
      if (sourceHash === recipe().identify.syx_sha256) {
        await t.test('X.20 loader readback', async () => {
          const r = await buildX20(input, recipe(), selected, core, opt);
          assert.deepEqual(r.report.firmware, FIRMWARE_VERSION);
          assert.deepEqual(findX20Layout(r.output, ['x20']), r.report.layout);
          assert.ok(r.report.gates.every(g => g.ok));
          const container = decodeSyx(r.output);
          // Independent of the stamping helper: the exact X.20 B startup-tag location.
          assert.equal(ascii(container.subarray(0x75340 - 0x4000, 0x75344 - 0x4000)), 'K01 ');
          assert.ok(r.report.gates.some(g => g.name === 'firmware-version' && g.ok));
          const stage = nrv2bDecode(container.subarray(8, 8 + u32(container, 0))).out;
          const offset = (a: number): number => R.loader.header + a - R.loader.stage2;
          const applier = offset(R.ram.bootCode[0]);
          assert.equal(Buffer.from(stage.subarray(applier, applier + 2)).toString('hex'), '41f9');
          let pos = offset(u32(stage, applier + 2));
          const ram = new Map<number, number>();
          for (let n = 0; ; n++) {
            assert.ok(n < 1000 && pos >= 0 && pos + 4 <= stage.length, 'bounded boot list');
            const address = u32(stage, pos); pos += 4;
            if (!address) break;
            const size = u32(stage, pos); pos += 4;
            assert.ok(size > 0 && pos + size <= stage.length);
            for (let k = 0; k < size; k++) {
              assert.ok(!ram.has(address + k), 'no overlapping boot writes');
              ram.set(address + k, stage[pos + k]);
            }
            pos += size + (size & 1);
          }
          const bytes = (at: number, n: number): Uint8Array => Uint8Array.from({ length: n }, (_, k) => {
            assert.ok(ram.has(at + k), `missing version byte ${(at + k).toString(16)}`);
            return ram.get(at + k)!;
          });
          assert.equal(ascii(bytes(0x2ad7a8, 4)), 'K.01');
          assert.equal(ascii(bytes(0x2b223e, 10)), 'OS K.01');
          assert.equal(ram.has(0x2ad7ac), false, 'existing short-label terminator untouched');
          assert.equal(await sha256(input), sourceHash);
          const bad = input.slice(); bad[100] ^= 1;
          await assert.rejects(buildX20(bad, recipe(), selected, core, opt), /hash differs/);
        });
        count++; continue;
      }
      let fw, base;
      try {
        try { fw = readFirmware(input); base = (await identify(fw, set)).base; }
        catch (e) {
          if (!(e instanceof NotPatchable) || e.profile?.id !== 'stock-163') continue;
          input = (await prepare163(input)).output;
          fw = readFirmware(input); base = (await identify(fw, set)).base;
        }
      } catch { continue; }
      if (seen.has(base.id)) continue;
      seen.add(base.id);
      await t.test(base.id, async () => {
        const hash = await sha256(input);
        const r = await build(input, base, selected, core, opt);
        const back = readFirmware(r.output);
        assert.equal(back.tag, 'K01 ');
        assert.deepEqual(r.report.firmware, FIRMWARE_VERSION);
        assert.equal(r.report.base, base.id);
        assert.ok(r.report.gates.every(g => g.ok));
        assert.deepEqual(findLayout(back)!.layout, r.report.layout);
        assert.deepEqual(back.flash.subarray(0, 0x4000), fw.flash.subarray(0, 0x4000));
        assert.deepEqual(back.slots[0].raw, fw.slots[0].raw);
        assert.deepEqual(back.data.map(s => s.raw), fw.data.map(s => s.raw));
        assert.equal(await sha256(input), hash);
      });
      count++;
    }
    assert.ok(count > 0, 'no supported input firmware found');
  });
