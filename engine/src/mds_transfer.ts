/** Closed-loop MDS sender: no open-loop fallback, including after a lost final ACK. */
import { CMD, decodeMessage, encodeMessage, hex, machineMessages, parseCaps, parseSlots, planBank, requireMds, type MdsAssignment, type MdsMachine, type MdsMessage, type MdsSnapshot } from './mds.js';

export interface MdsTransport { send(bytes: Uint8Array): void; receive(timeoutMs: number): Promise<Uint8Array | null> }
export const MIDI_CONNECTION_ERROR = 'You must plug in both MIDI IN and MIDI OUT to send Machines';
export interface TransferProgress { slot: number; alias: string; packet: number; packets: number; state: 'sending' | 'waiting' | 'retrying' | 'committed' }
const REASONS = ['', 'Malformed message', 'Unsupported version', 'Unsupported command', 'Invalid slot', 'Package too large', 'Corrupt data', 'Incompatible machine', 'Reserved reason', 'Receiver not ready', 'Slot in use', 'Device busy', 'Storage failure', 'DSP activation failure', 'Transaction conflict', 'Internal fault', 'DSP memory full', 'Machine library full', 'Cycle budget exceeded'];
function rejection(m: MdsMessage): Error {
  return new Error(m.command === CMD.cancel ? 'Device cancelled the transfer.' : `Device rejected the transfer: ${REASONS[m.body[1]] ?? `reason ${m.body[1]}`}.`);
}
export function sameLibrary(a: MdsSnapshot, b: MdsSnapshot): boolean {
  return a.generation === b.generation && a.slots.length === b.slots.length
    && (Object.keys(a.caps) as (keyof typeof a.caps)[]).every(k => a.caps[k] === b.caps[k])
    && a.slots.every((s, i) => (Object.keys(s) as (keyof typeof s)[]).every(k => s[k] === b.slots[i][k]));
}
export class MdsClient {
  private transaction = Math.floor(Math.random() * 16000) + 1;
  constructor(private readonly io: MdsTransport, private readonly now = () => performance.now(), private readonly timeout = 8000, private readonly waitLimit = 60000) {}
  private next(): number { this.transaction = (this.transaction + 1) % 16384; return this.transaction; }
  private async query(command: number, expected: number, connectionDeadline: number): Promise<Uint8Array> {
    const transaction = this.next(), wire = encodeMessage(command, transaction);
    for (let attempt = 0; attempt < 3; attempt++) {
      if (this.now() >= connectionDeadline) break;
      this.io.send(wire); let deadline = Math.min(connectionDeadline, this.now() + this.timeout);
      while (this.now() < deadline) {
        const bytes = await this.io.receive(Math.max(1, deadline - this.now())); if (!bytes) break;
        const reply = decodeMessage(bytes);
        if (reply.transaction !== transaction || reply.slot !== 127 || reply.sequence !== 127) continue;
        if (reply.command === expected) return reply.body;
        if (reply.command === CMD.wait && reply.body[0] === command) {
          requireMds(reply.body.length === 2, 'Malformed WAIT');
          // X.20 can answer a post-commit query with WAIT and no deferred
          // reply. Retry this read-only request after the two-second window,
          // without extending the shared five-second connection deadline.
          deadline = Math.min(deadline, this.now() + 2000);
        }
        if ((reply.command === CMD.nak || reply.command === CMD.cancel) && reply.body[0] === command) throw rejection(reply);
      }
    }
    throw new Error(MIDI_CONNECTION_ERROR);
  }
  async snapshot(): Promise<MdsSnapshot> {
    // One shared budget for the whole connection check, including retries.
    const deadline = this.now() + 5000;
    const first = parseSlots(await this.query(CMD.slots, CMD.slotsReply, deadline));
    const caps = parseCaps(await this.query(CMD.caps, CMD.capsReply, deadline));
    const last = parseSlots(await this.query(CMD.slots, CMD.slotsReply, deadline));
    requireMds(JSON.stringify(first) === JSON.stringify(last), 'Machine Bank changed while reading it. Read the bank again.');
    return { ...last, caps };
  }
  async send(machine: MdsMachine, slot: number, progress: (p: TransferProgress) => void = () => {}): Promise<void> {
    const packets = machineMessages(machine, slot, this.next()), parsed = packets.map(decodeMessage);
    const repairs = new Map<number, number>(), retries = new Map<number, number>(), started = new Map<number, number>();
    let index = 0;
    while (index < packets.length) {
      const m = parsed[index]; this.io.send(packets[index]);
      const report = (state: TransferProgress['state']) => progress({ slot, alias: machine.alias, packet: index, packets: packets.length, state }); report('sending');
      if (!started.has(index)) started.set(index, this.now());
      const absolute = started.get(index)! + this.waitLimit;
      let deadline = this.now() + this.timeout + packets[index].length / 3.125;
      for (;;) {
        requireMds(this.now() < absolute, 'Device stayed in WAIT too long. Read the bank before retrying.');
        const bytes = await this.io.receive(Math.max(1, Math.min(deadline, absolute) - this.now()));
        if (!bytes) {
          requireMds(this.now() < absolute, 'Device stayed in WAIT too long. Read the bank before retrying.');
          const count = (retries.get(index) ?? 0) + 1; retries.set(index, count);
          requireMds(count <= 3, 'Acknowledgment timed out. Installation status is unknown; read the bank before retrying.'); report('retrying'); break;
        }
        const r = decodeMessage(bytes);
        if (r.transaction !== m.transaction || r.slot !== m.slot) continue;
        if (r.command === CMD.ack) {
          requireMds(r.body.length === 14, 'Malformed acknowledgment');
          if (r.body[0] !== m.command || r.sequence !== m.sequence) continue;
          if (m.command === CMD.end) {
            requireMds(r.body[1] === 1 && hex(r.body.slice(6, 14)) === machine.contentId.slice(0, 16), 'Final acknowledgment did not confirm this machine was committed.'); report('committed');
          } else requireMds(r.body[1] === 0, 'Unexpected committed status before end of dump');
          index++; break;
        }
        if (r.command === CMD.wait) {
          requireMds(r.body.length === 2, 'Malformed WAIT');
          if (r.body[0] === m.command && r.sequence === m.sequence) { deadline = this.now() + 2000; report('waiting'); }
        } else if (r.command === CMD.nak) {
          requireMds(r.body.length === 4, 'Malformed NAK');
          if (r.body[1] === 6 && (r.body[2] || r.body[3])) {
            const target = parsed.findIndex(p => p.command === r.body[0] && p.sequence === r.sequence);
            requireMds(target >= 0 && target <= index + 1, 'Invalid repair request');
            const count = (repairs.get(target) ?? 0) + 1; repairs.set(target, count);
            requireMds(count === 1, 'Device rejected the same packet twice. Transfer stopped.'); index = target; break;
          }
          throw rejection(r);
        } else if (r.command === CMD.cancel) { requireMds(r.body.length === 2, 'Malformed CANCEL'); throw rejection(r); }
        // Unrelated traffic must not extend either deadline.
        if (this.now() >= deadline) { const count = (retries.get(index) ?? 0) + 1; retries.set(index, count); requireMds(count <= 3, 'Acknowledgment timed out.'); break; }
      }
    }
  }
  async install(assignments: MdsAssignment[], reviewed: MdsSnapshot, progress: (p: TransferProgress) => void, stopAfterMachine: () => boolean = () => false): Promise<{ snapshot: MdsSnapshot; stopped: boolean }> {
    let current = await this.snapshot();
    requireMds(sameLibrary(reviewed, current), 'The device bank changed since the connection check. Check the updated destinations and retry.');
    const plan = planBank(assignments, current); requireMds(!plan.problems.length, plan.problems.join(' '));
    for (const a of plan.changes) {
      if (stopAfterMachine()) return { snapshot: current, stopped: true };
      // A fresh read before every machine catches changes during a multi-machine installation.
      const before = await this.snapshot(); requireMds(sameLibrary(current, before), 'The bank changed during installation. Remaining transfers stopped.');
      await this.send(a.machine, a.slot, progress);
      const after = await this.snapshot(), slot = after.slots[a.slot];
      requireMds((slot.flags & 21) === 5 && slot.contentId === a.machine.contentId.slice(0, 16) && slot.words === a.machine.words && slot.bytes === a.machine.bytes.length, `U${a.slot + 1} did not verify after installation.`);
      requireMds(before.slots.every((s, i) => i === a.slot || JSON.stringify(s) === JSON.stringify(after.slots[i])), 'Another slot changed during installation. Remaining transfers stopped.');
      current = after;
    }
    return { snapshot: current, stopped: false };
  }
}
