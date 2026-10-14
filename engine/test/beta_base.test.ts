import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadBases, loadPacks } from '../src/node.js';
import { resolveBase } from '../src/bases.js';
import { readFirmware } from '../src/container.js';
import { sha256 } from '../src/bytes.js';
import { build } from '../src/build.js';
import { menuRefreshSite } from '../src/menu_refresh.js';
import { needsUwSamples } from '../src/packs.js';

const ROOT = fileURLToPath(new URL('../../../', import.meta.url));
const INPUT_HASH = '31be0d9b6ae9e6a49734909328f3dd2cb42e253c2d95e103d7489fc31a9bc6bd';
const FW = process.env.MD_FIRMWARE_DIR;

test('beta 26A09 has its own runtime evidence and does not inherit DEV option qualification', () => {
  const set = loadBases(join(ROOT, 'bases'));
  const profile = set.profiles.find(p => p.id === 'beta-26a09')!;
  assert.equal(profile.identify.tag, 'BETA');
  assert.equal(profile.qualification?.level, 'hardware-proven');
  assert.ok(profile.qualification?.evidence?.includes('docs/BASES.md#beta-26a09'));
  assert.ok(Object.values(profile.options!).every(o => !o.ok && o.why));
  const runtime = set.lineage.modelRuntimes!.find(r => r.id === profile.id)!;
  assert.equal(runtime.dsp2, profile.identify.dsp2_sha256);
  assert.equal(runtime.sram, 'e4230c932b2d77cd518eda754338a6a8be2d836dfb45cbdc46215b9da134c7b7');
  assert.equal(runtime.extensions, '4db841bc0121d843b159a915d778e2d2c8ab267f9f0c5d8462a56a3ef8fcb72d');
  assert.ok(runtime.evidence);
});

test('firmware: beta 26A09 discovers fresh sites and builds the catalog around its larger DSP2 upload',
  { skip: !FW || !existsSync(FW) ? 'MD_FIRMWARE_DIR is not set' : false }, async t => {
    let input: Uint8Array | undefined;
    for (const name of readdirSync(FW!).filter(n => /\.syx$/i.test(n))) {
      const bytes = readFileSync(join(FW!, name));
      if (await sha256(bytes) === INPUT_HASH) { input = bytes; break; }
    }
    if (!input) { t.skip('no md-26A09-132401-beta.syx in MD_FIRMWARE_DIR'); return; }
    const fw = readFirmware(input);
    const r = await resolveBase(fw, loadBases(join(ROOT, 'bases')));
    assert.equal(r.base.id, 'beta-26a09');
    assert.deepEqual(r.disagreements, []);
    assert.deepEqual(r.discovery.values, r.profile!.cache);
    assert.equal(r.base.modelRuntime?.ok, true);
    assert.equal(r.base.modelRuntime?.reusedFrom, 'beta-26a09');
    assert.equal(r.discovery.values['dsp2.free_regions'].split(',')[0], '0x13c600');
    const menu = menuRefreshSite(r.base, fw.slots[0].raw)!;
    assert.equal(menu.hook, 0x2c14a4);
    assert.equal(menu.count, 0x22c204);
    const { packs, core } = loadPacks(join(ROOT, 'catalog'));
    for (const uw of [true, false]) {
      const result = await build(input, r.base, packs, core, {
        uw, trim: { db: -30, minSeconds: 0.5, cap: 0.55 },
        exclude: uw ? [] : packs.flatMap(p => p.models).filter(needsUwSamples).map(m => m.module),
      });
      assert.ok(result.report.gates.every(g => g.ok), `UW=${uw}`);
      assert.equal(result.report.base, 'beta-26a09');
      assert.ok(result.report.machines.length >= 20);
      const output = readFirmware(result.output);
      assert.deepEqual(output.slots[0].raw, fw.slots[0].raw);
      assert.deepEqual(output.flash.subarray(fw.tailAt, fw.osEnd), fw.flash.subarray(fw.tailAt, fw.osEnd));
    }
    assert.equal(await sha256(input), INPUT_HASH, 'input firmware remains unchanged');
  });
