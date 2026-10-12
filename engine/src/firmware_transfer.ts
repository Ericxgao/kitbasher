// OS updates use paced, one-way SysEx, not the MDS request/acknowledgement protocol.
import { decodeSyx, encodeSyx, OS_LIMIT, OS_START } from './syx.js';

export const MIDI_BYTES_PER_SECOND = 3125; // 31,250 baud, ten bits per byte

/** Validate the entire update before sending anything; retain an immutable snapshot. */
export function firmwarePackets(bytes: Uint8Array): Uint8Array[] {
  if (!bytes.length || bytes.length > (OS_LIMIT - OS_START) * 2) throw new Error('Invalid firmware size. Rebuild the firmware and try again.');
  const snapshot = bytes.slice();
  const container = decodeSyx(snapshot);
  if (!container.length || container.length > OS_LIMIT - OS_START) throw new Error('Firmware is outside the OS update area.');
  const canonical = encodeSyx(container);
  if (canonical.length !== snapshot.length || !canonical.every((b, i) => b === snapshot[i])) {
    throw new Error('Invalid firmware messages. Rebuild the firmware and try again.');
  }
  const packets: Uint8Array[] = [];
  for (let start = 0; start < snapshot.length;) {
    const end = snapshot.indexOf(0xf7, start) + 1;
    packets.push(snapshot.subarray(start, end));
    start = end;
  }
  return packets;
}

export interface FirmwareProgress { sentBytes: number; totalBytes: number; remainingSeconds: number }
export interface FirmwareSender {
  send(message: Uint8Array): void;
  signal: AbortSignal;
  progress?(value: FirmwareProgress): void;
  /** Injectable clock and wait for deterministic protocol tests. */
  now?: () => number;
  wait?: (ms: number, signal: AbortSignal) => Promise<void>;
}

function wait(ms: number, signal: AbortSignal): Promise<void> {
  signal.throwIfAborted();
  return new Promise((resolve, reject) => {
    const abort = (): void => { clearTimeout(timer); reject(signal.reason); };
    const timer = setTimeout(() => { signal.removeEventListener('abort', abort); resolve(); }, Math.ceil(ms));
    signal.addEventListener('abort', abort, { once: true });
  });
}

/** Zero added gap. Never queue ahead or catch up after a delayed timer. */
export async function sendFirmware(bytes: Uint8Array, sender: FirmwareSender): Promise<void> {
  sender.signal.throwIfAborted();
  const packets = firmwarePackets(bytes);
  const now = sender.now ?? (() => performance.now());
  const pause = sender.wait ?? wait;
  let sentBytes = 0;
  const progress = (): void => sender.progress?.({ sentBytes, totalBytes: bytes.length,
    remainingSeconds: (bytes.length - sentBytes) / MIDI_BYTES_PER_SECOND });
  progress();
  for (const packet of packets) {
    sender.signal.throwIfAborted();
    sender.send(packet);
    const deadline = now() + packet.length * 1000 / MIDI_BYTES_PER_SECOND;
    // A timer can run early; explicitly ensure the full wire time has passed.
    while (now() < deadline) await pause(deadline - now(), sender.signal);
    sender.signal.throwIfAborted();
    sentBytes += packet.length;
    progress();
  }
}
