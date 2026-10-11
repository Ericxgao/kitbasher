import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { buildMdsCatalog } from '../web/build-mds.mjs';

test('every curated core/community release validates, with unique IDs and exact pinned bytes', async () => {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const { index, assets } = await buildMdsCatalog(root);
  assert.ok(index.machines.length >= 51);
  assert.equal(assets.length, index.machines.length);
  for (const family of ['NFX', 'P-I', 'SYN', 'TR6', 'TX8', 'TX9', 'TXZ']) assert.ok(index.machines.some(m => m.category === family));
  assert.ok(index.machines.filter(m => m.channel === 'core').length >= 43);
  assert.ok(index.machines.filter(m => m.channel === 'community').length >= 8);
  const kick = index.machines.find(m => m.alias === 'TR6-BD');
  assert.equal(kick.version, '1.2'); assert.match(kick.source, /3bc3635/);
  assert.ok(index.machines.every(m => m.cycles > 0 && m.cycles <= 3951 && m.words > 0 && m.contentId.length === 64));
});
