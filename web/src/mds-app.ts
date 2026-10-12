import { concat, hex, machineMessages, parsePackage, parseSysex, planBank, type MdsMachine, type MdsAssignment, type MdsSnapshot } from '../../engine/src/mds.js';
import { MdsClient, MIDI_CONNECTION_ERROR, sameLibrary } from '../../engine/src/mds_transfer.js';
import { BrowserMdsTransport } from './mds-midi.js';

interface CatalogEntry extends Omit<MdsMachine, 'bytes'> {
  packageBytes: number; channel: 'core' | 'community' | 'local'; author: string; summary: string;
  source: string | null; project: string | null; license: string; notes: string; sha256: string; url: string;
  hardware?: 'uw' | 'all';
}
const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
function node<K extends keyof HTMLElementTagNameMap>(tag: K, text = '', className = '') { const n = document.createElement(tag); n.textContent = text; if (className) n.className = className; return n; }
function button(label: string, action: () => void, title?: string) { const b = node('button', label); b.type = 'button'; b.onclick = action; if (title) { b.title = title; b.setAttribute('aria-label', title); } return b; }
const number = (n: number) => n.toLocaleString();
const slotName = (n: number) => `U${String(n + 1).padStart(2, '0')}`;
let entries: CatalogEntry[] = [], selection: MdsMachine[] = [], family = 'all', start = 0, busy = false, access: MIDIAccess | undefined;
let transport: BrowserMdsTransport | undefined, client: MdsClient | undefined, snapshot: MdsSnapshot | undefined;
let stop = false, dragIndex: number | undefined;
let primaryProgress = '';
const loaded = new Map<string, MdsMachine>();
const assignments = (): MdsAssignment[] => selection.map((machine, i) => ({ machine, slot: start + i }));
function bankProblems(problems: string[]): string { return [...new Set(problems.map(p => /^Remove \d+ (DSP words|package bytes)/.test(p) ? 'Not enough space. Remove a machine to continue.' : p))].join('\n'); }
function errorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  if (message.startsWith('No MDS reply')) return 'Your Machinedrum is not responding. Check both MIDI cables, the selected interface and X.20 firmware.';
  if (error instanceof Error && (error.name === 'NotAllowedError' || /permission denied/i.test(message))) return 'MIDI access was denied. Click Connect MIDI and allow access in Chrome.';
  return message;
}
function status(message: string, error = false) { $('mds-status').textContent = message; $('mds-status').dataset.error = String(error); }
function save() { try { localStorage.setItem('kitbasher-mds-bank', JSON.stringify({ start, ids: selection.map(m => m.contentId) })); } catch { /* Storage can be disabled. */ } }
function portsReady() {
  return access?.inputs.get($<HTMLSelectElement>('midi-input').value)?.state === 'connected'
    && access?.outputs.get($<HTMLSelectElement>('midi-output').value)?.state === 'connected';
}
function primaryAction() {
  if (!selection.length) return 'Choose machines';
  if (!access) return 'Connect MIDI';
  if (!portsReady()) return 'Choose MIDI device';
  if (!snapshot) return 'Try connection again';
  return 'Send machines';
}
function primaryWorking(label: string) { primaryProgress = label; $('flash-machines').textContent = label; $('flash-machines').setAttribute('aria-busy', 'true'); }
async function act(work: () => Promise<void>) {
  if (busy) return; busy = true; render();
  try { await work(); } catch (e) { const message = errorMessage(e); status($('midi-status').textContent === message ? '' : message, true); }
  finally { busy = false; primaryProgress = ''; render(); }
}
async function load(e: CatalogEntry): Promise<MdsMachine> {
  const known = loaded.get(e.contentId); if (known) return known;
  const response = await fetch(e.url); if (!response.ok) throw new Error(`Cannot load ${e.alias} (${response.status}).`);
  const data = new Uint8Array(await response.arrayBuffer());
  if (hex(new Uint8Array(await crypto.subtle.digest('SHA-256', data))) !== e.sha256) throw new Error(`${e.alias}: catalog file hash mismatch. Reload the page.`);
  const machines = e.url.endsWith('.mds') ? [await parsePackage(data)] : await parseSysex(data);
  if (machines.length !== 1 || machines[0].contentId !== e.contentId) throw new Error(`${e.alias}: catalog identity mismatch.`);
  loaded.set(e.contentId, machines[0]); return machines[0];
}
function filtered(): CatalogEntry[] {
  const search = $<HTMLInputElement>('machine-search').value.toLowerCase(), collection = $<HTMLSelectElement>('collection-filter').value;
  const result = entries.filter(e => (family === 'all' || family === e.category) && (collection === 'all' || collection === e.channel) && `${e.alias} ${e.name} ${e.author} ${e.summary}`.toLowerCase().includes(search));
  const sort = $<HTMLSelectElement>('machine-sort').value;
  if (sort !== 'curated') result.sort((a, b) => (sort === 'smallest' ? a.words - b.words : sort === 'cpu' ? a.cycles - b.cycles : 0) || a.alias.localeCompare(b.alias)); return result;
}
function add(e: CatalogEntry) { void act(async () => { if (selection.length + start >= 16) throw new Error('All 16 slots are full. Remove a machine to add another.'); selection.push(await load(e)); save(); status(`${e.alias} added to ${slotName(start + selection.length - 1)}.`); }); }
function remove(index: number) { selection.splice(index, 1); save(); render(); }
function move(from: number, to: number) { if (busy || from === to || to < 0 || to >= selection.length) return; const [m] = selection.splice(from, 1); selection.splice(to, 0, m); save(); render(); ($('bank-slots').children[start + to] as HTMLElement)?.focus(); status(`${m.alias} moved to ${slotName(start + to)}.`); }
function render() {
  $('catalog-count').textContent = String(entries.length);
  const familyFilter = $<HTMLSelectElement>('family-filter'); familyFilter.replaceChildren(new Option('All families', 'all'));
  for (const f of new Set(entries.map(e => e.category))) familyFilter.append(new Option(f, f));
  familyFilter.value = family;
  const list = $('machine-list'); list.replaceChildren(); const shown = filtered();
  for (const e of shown) {
    const selected = selection.findIndex(m => m.contentId === e.contentId), row = node('tr'); row.dataset.selected = String(selected >= 0);
    const nameCell = node('td'), name = button(e.alias, () => details(e)); name.className = 'machine-name';
    nameCell.append(name, node('span', e.summary, 'machine-subtitle'));
    if (e.hardware === 'uw') nameCell.append(node('span', 'Requires a UW model', 'machine-subtitle'));
    const pick = node('td'), b = button(selected < 0 ? 'Add' : 'Added', () => selected < 0 ? add(e) : remove(selected), selected < 0 ? `Add ${e.alias}` : `Remove ${e.alias}`); b.className = 'pick-button'; b.setAttribute('aria-pressed', String(selected >= 0)); pick.append(b);
    row.append(nameCell, pick); list.append(row);
  }
  $('empty-library').hidden = shown.length > 0;
  const plan = planBank(assignments(), snapshot);
  $('selection-count').textContent = `${selection.length} selected`;
  $('capacity-mode').textContent = snapshot ? 'Includes machines already on your device.' : 'Estimate for an empty bank. Connect MIDI to check your device.';
  const used = Math.ceil(Math.max(plan.words / plan.caps.totalWords, plan.bytes / plan.caps.totalBytes) * 100);
  const space = $('space-summary'), spaceText = node('div'), spaceBar = node('progress');
  space.dataset.over = String(used > 100); spaceBar.max = 100; spaceBar.value = Math.min(100, used);
  spaceBar.setAttribute('aria-label', `${used}% of bank space used`);
  spaceText.append(node('span', snapshot ? 'Bank space' : 'Estimated space'), node('span', `${used}% used · ${plan.occupied}/16 slots`));
  space.replaceChildren(spaceText, spaceBar);
  $('empty-bank').hidden = plan.occupied > 0;
  $('reorder-hint').hidden = selection.length < 2;
  $('send-hint').hidden = !selection.length || !snapshot;
  $('midi-help').hidden = !!snapshot;
  if (access && !snapshot) $<HTMLDetailsElement>('connection').open = true;
  const meters = $('capacity-meters'); meters.replaceChildren();
  for (const [label, value, max, unit] of [['DSP memory', plan.words, plan.caps.totalWords, 'words'], ['Package storage', plan.bytes, plan.caps.totalBytes, 'bytes'], ['Slots', plan.occupied, 16, '']] as const) {
    const wrap = node('div', '', 'mds-meter'), text = node('div'), bar = node('progress'); wrap.dataset.over = String(value > max);
    text.append(node('span', label), node('span', `${number(value)} / ${number(max)} ${unit}`)); bar.max = max; bar.value = Math.min(max, value); bar.setAttribute('aria-label', `${label}: ${value} of ${max} ${unit}`); wrap.append(text, bar); meters.append(wrap);
  }
  const slots = $('bank-slots'); slots.replaceChildren();
  for (let i = 0; i < 16; i++) {
    const index = i - start, m = selection[index], installed = snapshot?.slots[i], row = node('li', '', 'mds-slot'); row.dataset.selected = String(!!m);
    row.hidden = !m && !((installed?.flags ?? 0) & 1);
    row.append(node('span', slotName(i), 'slot-number'));
    const label = node('span', m?.alias ?? ((installed?.flags ?? 0) & 1 ? installed!.alias : 'Empty'), `slot-name${!m ? ' empty' : ''}`);
    if (m && installed && (installed.flags & 1)) label.append(node('span', installed.contentId === m.contentId.slice(0, 16) ? 'Installed' : 'Replace', 'slot-note'));
    else if (!m && installed && (installed.flags & 1)) label.append(node('span', 'Keep', 'slot-note'));
    row.append(label);
    if (m) {
      const actions = node('span', '', 'slot-buttons');
      const del = button('×', () => remove(index), `Remove ${m.alias} from bank`);
      actions.append(del); row.append(actions); row.tabIndex = busy ? -1 : 0;
      row.setAttribute('aria-label', `${slotName(i)} ${m.alias}. Arrow keys reorder.`);
      row.onkeydown = event => { if (event.target === row && ['ArrowUp', 'ArrowDown'].includes(event.key)) { event.preventDefault(); move(index, index + (event.key === 'ArrowUp' ? -1 : 1)); } };
      row.draggable = !busy; row.ondragstart = event => { dragIndex = index; event.dataTransfer?.setData('text/plain', String(index)); }; row.ondragover = event => { if (!busy && dragIndex !== undefined) { event.preventDefault(); row.dataset.dragOver = 'true'; } }; row.ondragleave = () => { delete row.dataset.dragOver; }; row.ondrop = event => { event.preventDefault(); if (dragIndex !== undefined) move(dragIndex, index); dragIndex = undefined; }; row.ondragend = () => { dragIndex = undefined; delete row.dataset.dragOver; };
    }
    slots.append(row);
  }
  $('bank-problems').textContent = bankProblems(plan.problems);
  $('add-family').hidden = family === 'all';
  $<HTMLButtonElement>('add-family').disabled = family === 'all' || !shown.some(e => !selection.some(m => m.contentId === e.contentId));
  $<HTMLButtonElement>('clear-selection').disabled = !selection.length; $<HTMLButtonElement>('sort-selection').disabled = selection.length < 2;
  $<HTMLButtonElement>('download-bank').disabled = !selection.length || plan.problems.length > 0;
  $<HTMLButtonElement>('flash-machines').disabled = false;
  $('flash-machines').textContent = primaryProgress || primaryAction();
  $('flash-machines').setAttribute('aria-busy', String(!!primaryProgress));
  $<HTMLButtonElement>('disconnect-midi').disabled = !access;
  $('disconnect-midi').hidden = !access;
  $<HTMLSelectElement>('start-slot').value = String(start);
  for (const option of $<HTMLSelectElement>('start-slot').options) option.disabled = Number(option.value) + selection.length > 16;
  if (busy) {
    for (const control of document.querySelectorAll<HTMLButtonElement | HTMLSelectElement | HTMLInputElement>('button,select,input')) if (!['stop-transfer', 'close-details'].includes(control.id)) control.disabled = true;
  }
  // Restore static controls after busy operations (dynamic ones were rebuilt).
  if (!busy) for (const id of ['machine-search', 'collection-filter', 'machine-sort', 'family-filter', 'start-slot', 'import-machines', 'midi-input', 'midi-output', 'theme-toggle']) $<HTMLInputElement>(id).disabled = false;
}
function external(label: string, href: string) { const a = node('a', label); const url = new URL(href, location.href); if (!['https:', 'http:'].includes(url.protocol)) return node('span', label); a.href = url.href; a.target = '_blank'; a.rel = 'noopener'; return a; }
function details(e: CatalogEntry) {
  $('detail-title').textContent = e.alias; const body = $('detail-body'); body.replaceChildren(node('p', e.summary));
  const dl = node('dl', '', 'mds-details-grid');
  for (const [name, value] of [['Author', e.author], ['Version', e.version], ['DSP memory', `${number(e.words)} words`], ['Storage', `${number(e.packageBytes)} bytes`], ['Declared CPU', `${(e.cycles / 32).toFixed(2)} clocks/sample`], ['License', e.license]]) { const box = node('div'); box.append(node('dt', name), node('dd', value)); dl.append(box); }
  const technical = node('details', '', 'mds-technical'); technical.append(node('summary', 'Technical details'), dl, node('h3', 'Controls'));
  const controls = node('div', '', 'mds-controls');
  for (const p of e.parameters) controls.append(node('div', `${p.name} · ${p.min}–${p.max} · default ${p.default}`, 'mds-control')); technical.append(controls);
  if (e.notes) body.append(node('p', e.notes));
  if (e.hardware) body.append(node('p', e.hardware === 'uw' ? 'Requires a Machinedrum UW, as specified by the author.' : 'Supports UW and non-UW Machinedrums, as specified by the author.'));
  if (e.tonal) body.append(node('p', 'Tonal machine with pitch control.'));
  if (e.neighbour) body.append(node('p', 'Neighbour machine: processes audio from preceding tracks.'));
  if (e.stereoPair) body.append(node('p', 'Supports stereo pairing when the same installed machine is assigned to adjacent tracks. Pan the tracks apart for stereo.'));
  const links = node('p'); if (e.source) links.append(external('Machine source', e.source)); else links.append(node('span', 'Machine source is not published in this catalog.'));
  if (e.project) links.append(node('span', ' · '), external('Project', e.project)); body.append(links);
  technical.append(node('p', 'CPU cost is the package author’s declaration, not a measurement by this browser.', 'fine')); body.append(technical);
  $<HTMLDialogElement>('machine-details').showModal();
}
function populatePorts() {
  if (!access) return;
  for (const [id, ports] of [['midi-input', [...access.inputs.values()]], ['midi-output', [...access.outputs.values()]]] as const) {
    const select = $<HTMLSelectElement>(id), previous = select.value; select.replaceChildren();
    select.append(new Option('Choose a port', ''));
    for (const port of ports.filter(p => p.state === 'connected')) select.append(new Option(port.name ?? port.id, port.id));
    if (ports.some(p => p.id === previous && p.state === 'connected')) select.value = previous;
    else if (select.options.length === 2) select.selectedIndex = 1;
  }
}
async function closeTransport() { const old = transport; transport = undefined; client = undefined; snapshot = undefined; if (old) await old.close(); }
async function readBank() {
  primaryWorking('Checking MIDI connection…');
  await closeTransport();
  const input = access?.inputs.get($<HTMLSelectElement>('midi-input').value), output = access?.outputs.get($<HTMLSelectElement>('midi-output').value);
  $('midi-status').dataset.error = 'false'; $('midi-status').textContent = 'Checking your Machinedrum…';
  try {
    if (!output || output.state !== 'connected' || !input || input.state !== 'connected') throw new Error(MIDI_CONNECTION_ERROR);
    transport = new BrowserMdsTransport(input, output);
    await Promise.all([input.open(), output.open()]); client = new MdsClient(transport); snapshot = await client.snapshot();
    $('midi-status').textContent = 'Machinedrum connected.'; $<HTMLDetailsElement>('connection').open = false;
  } catch (e) { await closeTransport(); $('midi-status').dataset.error = 'true'; $('midi-status').textContent = errorMessage(e); throw e; }
}
async function connectMidi() {
  primaryWorking('Connecting MIDI…');
  if (!navigator.requestMIDIAccess || !isSecureContext) throw new Error('Open this page in Chrome to send machines over MIDI.');
  access = await navigator.requestMIDIAccess({ sysex: true });
  if (!access.sysexEnabled) { access = undefined; throw new Error('Allow MIDI access, including SysEx, when Chrome asks. Then try again.'); }
  $('connection').hidden = false; populatePorts();
  access.onstatechange = () => {
    if (transport && (transport.input.state !== 'connected' || transport.output.state !== 'connected')) { snapshot = undefined; $('midi-status').dataset.error = 'true'; $('midi-status').textContent = 'MIDI disconnected. Reconnect both cables and try again.'; status('MIDI disconnected. Reconnect both cables and try again.', true); }
    if (!busy) { populatePorts(); render(); }
  };
  if (portsReady()) await readBank();
  else { $('midi-status').dataset.error = 'true'; $('midi-status').textContent = MIDI_CONNECTION_ERROR; }
}
$('disconnect-midi').onclick = () => void act(async () => { if (access) access.onstatechange = null; await closeTransport(); access = undefined; $('connection').hidden = true; $('midi-status').dataset.error = 'false'; $('midi-status').textContent = 'Connect your MIDI interface to both IN and OUT on your Machinedrum.'; status('MIDI disconnected.'); });
for (const id of ['midi-input', 'midi-output']) $(id).onchange = () => void act(async () => { if (portsReady()) await readBank(); else { await closeTransport(); $('midi-status').dataset.error = 'true'; $('midi-status').textContent = MIDI_CONNECTION_ERROR; } });
$('family-filter').onchange = () => { family = $<HTMLSelectElement>('family-filter').value; render(); };
for (const id of ['machine-search', 'collection-filter', 'machine-sort']) $(id).addEventListener(id === 'machine-search' ? 'input' : 'change', render);
$('start-slot').onchange = () => { start = Number($<HTMLSelectElement>('start-slot').value); save(); render(); };
$('clear-selection').onclick = () => { selection = []; save(); render(); status('Selection cleared. Nothing changed on the device.'); };
$('sort-selection').onclick = () => { selection.sort((a, b) => a.alias.localeCompare(b.alias)); save(); render(); };
$('add-family').onclick = () => void act(async () => {
  const add = filtered().filter(e => !selection.some(m => m.contentId === e.contentId));
  if (selection.length + add.length + start > 16) throw new Error('Not enough free slots for the whole family. Add individual machines instead.');
  const machines = await Promise.all(add.map(load)); selection.push(...machines); save(); status(`Added ${machines.length} ${family} machines.`);
});
$('import-machines').onchange = () => void act(async () => {
  const input = $<HTMLInputElement>('import-machines'), files = [...(input.files ?? [])]; input.value = '';
  const staged: MdsMachine[] = [];
  if (files.length > 64) throw new Error('Import at most 64 files at a time.');
  for (const file of files) { if (file.size > 2_000_000) throw new Error(`${file.name} is too large.`); const bytes = new Uint8Array(await file.arrayBuffer()); staged.push(...(file.name.toLowerCase().endsWith('.mds') ? [await parsePackage(bytes)] : await parseSysex(bytes))); }
  for (const m of staged) {
    if (entries.some(e => e.contentId === m.contentId)) continue;
    const { bytes, ...meta } = m; entries.push({ ...meta, packageBytes: bytes.length, channel: 'local', author: 'Local import', summary: m.name, source: null, project: null, license: 'See original release', notes: 'Imported in this browser session. It has not been added to the public catalog.', sha256: '', url: '' }); loaded.set(m.contentId, m);
  }
  $<HTMLSelectElement>('collection-filter').value = 'local'; family = 'all'; status(`Validated ${staged.length} imported machine packages. Local files stay in this browser.`);
});
$('download-bank').onclick = () => void act(async () => {
  const current = assignments(), plan = planBank(current, snapshot); if (!current.length || plan.problems.length) throw new Error('Resolve bank capacity before exporting.');
  const bytes = concat(current.flatMap((a, i) => machineMessages(a.machine, a.slot, i + 1)));
  const url = URL.createObjectURL(new Blob([bytes as Uint8Array<ArrayBuffer>], { type: 'application/octet-stream' })), a = node('a'); a.href = url; a.download = 'kitbasher-mds-bank.syx'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  status(`Downloaded ${current.length} selected machines for ${slotName(start)}–${slotName(start + selection.length - 1)}. Use this page to send the file to your Machinedrum.`);
});
$('close-details').onclick = () => $<HTMLDialogElement>('machine-details').close();
$('flash-machines').onclick = async () => { await act(async () => {
  try {
    if (!selection.length) { status('Add machines from the library to begin.'); return; }
    if (!access) { await connectMidi(); return; }
    if (!portsReady()) { populatePorts(); await readBank(); return; }
    // A retry restores the ready state; only a click labelled Send machines writes.
    if (!snapshot) { await readBank(); return; }
  const run = async () => {
    const preview = snapshot;
    await readBank();
    if (!client || !snapshot) throw new Error('MIDI connection could not be verified.');
    if (preview && !sameLibrary(preview, snapshot)) throw new Error('The bank on your Machinedrum changed. Check the updated selection before sending again.');
    const selected = assignments(), plan = planBank(selected, snapshot), connection = client, baseline = snapshot;
    if (plan.problems.length) throw new Error(bankProblems(plan.problems));
    if (!plan.changes.length) { status('These machines are already installed.'); return; }
    primaryWorking('Sending machines…');
    stop = false; $('transfer-panel').hidden = false; $<HTMLButtonElement>('stop-transfer').disabled = false;
    const total = plan.changes.reduce((n, a) => n + Math.ceil(a.machine.bytes.length / 420) + 2, 0);
    let finished = 0; const progress = $<HTMLProgressElement>('transfer-progress'); progress.max = total; progress.value = 0;
    try {
      const result = await connection.install(selected, baseline, event => {
        progress.value = finished + event.packet; $('transfer-status').textContent = event.state === 'committed' ? `${event.alias} installed.` : `Sending ${event.alias}…`;
        if (event.state === 'committed') { finished += event.packets; progress.value = finished; }
      }, () => stop);
      snapshot = result.snapshot; const message = result.stopped ? 'Stopped. Machines already sent are installed.' : 'Done. Your machines are installed.';
      $('transfer-status').textContent = message; status(message);
    } catch (e) { snapshot = undefined; $('transfer-status').textContent = 'Sending stopped. Some machines may already be installed. Reconnect to check before trying again.'; throw e; }
    finally { $<HTMLButtonElement>('stop-transfer').disabled = true; }
  };
  if (navigator.locks) await navigator.locks.request('kitbasher-mds-midi', { ifAvailable: true }, async lock => { if (!lock) throw new Error('Another Kitbasher tab is using MIDI. Finish that transfer first.'); await run(); }); else await run();
  } catch (e) { $('midi-status').dataset.error = 'true'; $('midi-status').textContent = errorMessage(e); throw e; }
});
  if (!selection.length) { $('machine-search').scrollIntoView({ block: 'center' }); $('machine-search').focus(); }
  else if (access && !portsReady()) {
    const missing = access.outputs.get($<HTMLSelectElement>('midi-output').value)?.state === 'connected' ? $('midi-input') : $('midi-output');
    missing.scrollIntoView({ block: 'center' }); missing.focus();
  }
};
$('stop-transfer').onclick = () => { stop = true; $<HTMLButtonElement>('stop-transfer').disabled = true; $('transfer-status').textContent = 'Finishing this machine, then stopping.'; };
window.addEventListener('beforeunload', event => { if (busy && !$('transfer-panel').hidden) { event.preventDefault(); event.returnValue = ''; } });
window.addEventListener('pagehide', () => { void transport?.close(); });
function theme() { const dark = document.documentElement.dataset.theme === 'dark'; $('theme-toggle').textContent = dark ? 'Light mode' : 'Dark mode'; }
$('theme-toggle').onclick = () => { document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'; try { localStorage.setItem('kitbasher-theme', document.documentElement.dataset.theme); } catch {} theme(); }; theme();
for (let i = 0; i < 16; i++) $<HTMLSelectElement>('start-slot').append(new Option(slotName(i), String(i)));
void act(async () => {
  const response = await fetch('data/mds/index.json'); if (!response.ok) throw new Error('The machine catalog could not load. Refresh to retry.');
  const catalog = await response.json(); if (catalog.schema !== 'kitbasher.mds-catalog/1' || !Array.isArray(catalog.machines)) throw new Error('Unsupported catalog.'); entries = catalog.machines;
  let saved: { start?: number; ids?: string[] } = {}; try { saved = JSON.parse(localStorage.getItem('kitbasher-mds-bank') ?? '{}'); } catch {}
  if (Number.isInteger(saved.start) && saved.start! >= 0 && saved.start! < 16) start = saved.start!;
  const ids = Array.isArray(saved.ids) ? [...new Set(saved.ids)].slice(0, 16 - start) : [];
  const restore = ids.flatMap(id => { const e = entries.find(e => e.contentId === id); return e ? [e] : []; }); selection = await Promise.all(restore.map(load));
  status('');
});
