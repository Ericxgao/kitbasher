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
  const machines = [], assets = [], ids = new Set(), contentIds = new Set(), aliases = new Set();
  for (const entry of catalog.machines) {
    if (!entry || typeof entry !== 'object' || typeof entry.file !== 'string') throw new Error('MDS catalog entries need a file path');
    const path = resolve(root, entry.file);
    if (!path.startsWith(resolve(root, 'mds') + sep) || !/\.(syx|mds)$/.test(path)) throw new Error('MDS catalog file must be under mds/');
    if (!['core', 'community'].includes(entry.channel) || ['author', 'summary', 'license'].some(field => typeof entry[field] !== 'string' || !entry[field].trim())) throw new Error(`Missing curation metadata: ${entry.file}`);
    if (typeof entry.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(entry.sha256)) throw new Error(`Invalid SHA-256 pin: ${entry.file}`);
    if (entry.notes !== undefined && typeof entry.notes !== 'string') throw new Error(`Catalog notes must be text: ${entry.file}`);
    if (entry.hidden !== undefined && typeof entry.hidden !== 'boolean') throw new Error(`Catalog hidden must be boolean: ${entry.file}`);
    if (entry.hardware !== undefined && !['uw', 'all'].includes(entry.hardware)) throw new Error(`Catalog hardware must be uw or all: ${entry.file}`);
    for (const field of ['source', 'project']) if (entry[field] !== null && (typeof entry[field] !== 'string' || new URL(entry[field]).protocol !== 'https:')) throw new Error('Catalog links must be HTTPS URLs or null');
    const bytes = readFileSync(path), hash = createHash('sha256').update(bytes).digest('hex');
    if (hash !== entry.sha256) throw new Error(`MDS hash changed: ${entry.file}. Review the release and update its catalog pin.`);
    const parsed = path.endsWith('.mds') ? [await parsePackage(bytes)] : await parseSysex(bytes);
    if (parsed.length !== 1) throw new Error('Catalog entries must contain one machine each');
    const { bytes: packageBytes, ...machine } = parsed[0];
    // Some original community variants retain their parent descriptor ID. Require
    // an explicit, exact-ID exception; selection and MIDI identity use contentId.
    if (entry.sharedId !== undefined && entry.sharedId !== machine.id) throw new Error(`Shared ID must match the package: ${entry.file}`);
    if (!machine.id || (entry.sharedId === undefined && ids.has(machine.id))) throw new Error(`Duplicate/empty MDS ID: ${machine.id}`);
    if (entry.sharedId === undefined) ids.add(machine.id);
    if (contentIds.has(machine.contentId) || aliases.has(machine.alias)) throw new Error(`Duplicate MDS content or alias: ${machine.alias}`);
    contentIds.add(machine.contentId); aliases.add(machine.alias);
    if (machine.cycles > 3951) throw new Error(`Uninstallable cycle declaration: ${machine.alias}`);
    if (entry.hidden) continue;
    const file = `${hash}.${path.endsWith('.mds') ? 'mds' : 'syx'}`;
    machines.push({ ...machine, packageBytes: packageBytes.length, channel: entry.channel, author: entry.author, summary: entry.summary, source: entry.source, project: entry.project, license: entry.license, notes: entry.notes, hardware: entry.hardware, sha256: hash, url: `data/mds/${file}` });
    assets.push({ file, bytes });
  }
  return { index: { schema: catalog.schema, machines }, assets };
}
