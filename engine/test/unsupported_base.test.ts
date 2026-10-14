// X.13 is not supported: an OS with its tag is refused before discovery, in one line, whatever its
// slot hashes, so it is never patched or taken for X.14.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { NotPatchable, resolveBase, unsupported } from '../src/bases.js';
import type { Firmware } from '../src/container.js';
import { loadBases, loadPacks } from '../src/node.js';
import { assertRecipeSupported, recipeFor } from '../src/x20_recipe.js';
import { buildX20 } from '../src/x20.js';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const set = loadBases(resolve(ROOT, 'bases'));

test('X.20 remains identifiable but is refused by the shipped recipe and direct builds', async () => {
  const recipe = set.recipes.find(r => r.id === 'x20')!;
  const message = 'X.20 is currently not supported.';
  assert.equal(recipe.refuse, message);
  assert.equal(recipeFor(set.recipes, recipe.identify.syx_sha256), recipe);
  assert.throws(() => assertRecipeSupported(recipe), { message });
  const { packs, core } = loadPacks(resolve(ROOT, 'catalog'));
  await assert.rejects(buildX20(new Uint8Array(), recipe, packs, core,
    { uw: true, trim: { db: -30, minSeconds: 0.5, cap: 0.55 } }), { message });
  await assert.rejects(resolveBase({ tag: 'X20 ' } as Firmware, set), { message });
});

test('an OS tagged X13 is refused before anything is hashed or discovered', async () => {
  const fw = { tag: 'X13 ' } as unknown as Firmware;            // no slots: the tag alone decides
  await assert.rejects(resolveBase(fw, set), (e: unknown) => {
    assert.ok(e instanceof NotPatchable);
    assert.equal(e.discovery, null);
    assert.equal(e.message, 'OS X.13 is not supported. Load an OS X.14 file.');
    return true;
  });
});

test('retired DEV firmware is refused before discovery, including unprofiled DEV builds', async () => {
  await assert.rejects(resolveBase({ tag: 'DEV ' } as Firmware, set), (e: unknown) => {
    assert.ok(e instanceof NotPatchable);
    assert.equal(e.discovery, null);
    assert.match(e.message, /no longer supported.*md-26A09-132401-beta.syx/);
    return true;
  });
});

test('no base profile or model runtime is for a retired base, and supported tags are not refused', () => {
  assert.ok(!set.profiles.some((p) => p.id === 'x13' || unsupported(p.identify.tag)));
  assert.ok(!(set.lineage.modelRuntimes ?? []).some((r) => r.id === 'x13' || r.id.startsWith('dev-')));
  assert.equal(unsupported('X14 '), null);
  assert.equal(unsupported('BETA'), null);
  assert.equal(set.profiles.find(p => p.id === 'beta-26a09')?.identify.tag, 'BETA');
});
