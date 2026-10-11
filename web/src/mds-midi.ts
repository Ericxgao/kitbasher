import { MDS_PREFIX } from '../../engine/src/mds.js';
import type { MdsTransport } from '../../engine/src/mds_transfer.js';

/** One selected input/output pair. Permission and selection happen in the UI. */
export class BrowserMdsTransport implements MdsTransport {
  private queue: Uint8Array[] = [];
  private pending?: { resolve: (bytes: Uint8Array | null) => void; reject: (error: Error) => void; timer: ReturnType<typeof setTimeout> };
  private closed = false;
  constructor(readonly input: MIDIInput, readonly output: MIDIOutput) { input.addEventListener('midimessage', this.onMessage); input.addEventListener('statechange', this.onState); output.addEventListener('statechange', this.onState); }
  private onMessage = (event: MIDIMessageEvent) => {
    const b = new Uint8Array(event.data ?? []).filter(n => n < 248);
    if (!MDS_PREFIX.every((n, i) => b[i] === n)) return;
    if (this.pending) { clearTimeout(this.pending.timer); const p = this.pending; this.pending = undefined; p.resolve(b); }
    else if (this.queue.length < 64) this.queue.push(b);
    else this.fail(new Error('MIDI reply queue overflow. Disconnect and retry.'));
  };
  private onState = () => { if (this.input.state !== 'connected' || this.output.state !== 'connected') this.fail(new Error('MIDI device disconnected. Reconnect both MIDI directions before retrying.')); };
  private fail(error: Error) { this.closed = true; if (this.pending) { clearTimeout(this.pending.timer); this.pending.reject(error); this.pending = undefined; } }
  send(bytes: Uint8Array) { this.onState(); if (this.closed) throw new Error('MIDI connection is closed. Both MIDI input and output must be connected.'); this.output.send(Array.from(bytes)); }
  receive(timeoutMs: number): Promise<Uint8Array | null> {
    if (this.closed) return Promise.reject(new Error('MIDI connection is closed.'));
    if (this.pending) return Promise.reject(new Error('A MIDI read is already active.'));
    const item = this.queue.shift(); if (item) return Promise.resolve(item);
    return new Promise((resolve, reject) => { this.pending = { resolve, reject, timer: setTimeout(() => { this.pending = undefined; resolve(null); }, timeoutMs) }; });
  }
  async close() {
    this.fail(new Error('MIDI connection closed.')); this.input.removeEventListener('midimessage', this.onMessage); this.input.removeEventListener('statechange', this.onState); this.output.removeEventListener('statechange', this.onState);
    this.queue = []; await Promise.allSettled([this.input.close(), this.output.close()]);
  }
}
