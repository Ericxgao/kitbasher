import { build } from 'esbuild';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, sep } from 'node:path';

/** Content-addressed static catalog. Every artifact must pass the same decoder as local imports. */
export async function buildMdsCatalog(root) {
  const compiled = await build({ entryPoints: [resolve(root, 'engine/src/mds.ts')], bundle: true, format: 'esm', platform: 'neutral', write: false, logLevel: 'silent' });
  const { parsePackage, parseSysex } = await import('data:text/javascript;base64,' + Buffer.from(compiled.outputFiles[0].contents).toString('base64'));
  const catalog = JSON.parse(readFileSync(resolve(root, 'mds/catalog.json'), 'utf8'));
  if (catalog.schema !== 'kitbasher.mds-catalog/1' || !Array.isArray(catalog.machines)) throw new Error('Invalid MDS catalog');
  const machines = [], assets = [], ids = new Set();
  for (const entry of catalog.machines) {
    const path = resolve(root, entry.file);
    if (!path.startsWith(resolve(root, 'mds') + sep) || !/\.(syx|mds)$/.test(path)) throw new Error('MDS catalog file must be under mds/');
    if (!['core', 'community'].includes(entry.channel) || !entry.author || !entry.summary) throw new Error(`Missing curation metadata: ${entry.file}`);
    for (const field of ['source', 'project']) if (entry[field] && new URL(entry[field]).protocol !== 'https:') throw new Error('Catalog links must use HTTPS');
    const bytes = readFileSync(path), hash = createHash('sha256').update(bytes).digest('hex');
    if (hash !== entry.sha256) throw new Error(`MDS hash changed: ${entry.file}. Review the release and update its catalog pin.`);
    const parsed = path.endsWith('.mds') ? [await parsePackage(bytes)] : await parseSysex(bytes);
    if (parsed.length !== 1) throw new Error('Catalog entries must contain one machine each');
    const { bytes: packageBytes, ...machine } = parsed[0];
    if (!machine.id || ids.has(machine.id)) throw new Error(`Duplicate/empty MDS ID: ${machine.id}`); ids.add(machine.id);
    if (machine.cycles > 3951) throw new Error(`Uninstallable cycle declaration: ${machine.alias}`);
    const file = `${hash}.${path.endsWith('.mds') ? 'mds' : 'syx'}`;
    machines.push({ ...machine, packageBytes: packageBytes.length, channel: entry.channel, author: entry.author, summary: entry.summary, source: entry.source, project: entry.project, license: entry.license, notes: entry.notes, sha256: hash, url: `data/mds/${file}` });
    assets.push({ file, bytes });
  }
  return { index: { schema: catalog.schema, machines }, assets };
}
