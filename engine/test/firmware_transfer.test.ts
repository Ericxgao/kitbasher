import { test } from 'node:test';
import assert from 'node:assert/strict';
import { encodeSyx, OS_LIMIT, OS_START } from '../src/syx.js';
import { firmwarePackets, sendFirmware, MIDI_BYTES_PER_SECOND } from '../src/firmware_transfer.js';

const update = (): Uint8Array => encodeSyx(Uint8Array.from({ length: 130 }, (_, i) => i & 255));

test('validates every packet including end markers before sending', async () => {
  const good = update();
  assert.equal(firmwarePackets(good).length, 5);
  const checksum = good.slice(); checksum[7] ^= 1;
  const address = good.slice(); address[14] ^= 1;
  const badEnd = good.slice(); badEnd[badEnd.length - 2] ^= 1;
  const trailing = new Uint8Array([...good, 0]);
  const missingMarker = new Uint8Array([...good.slice(0, -22), ...good.slice(-14)]);
  for (const bad of [checksum, address, badEnd, trailing, missingMarker, good.slice(0, -1), encodeSyx(new Uint8Array()),
    encodeSyx(new Uint8Array(OS_LIMIT - OS_START + 2))]) {
    let sends = 0;
    await assert.rejects(sendFirmware(bad, { signal: new AbortController().signal, send: () => { sends++; } }));
    assert.equal(sends, 0);
  }
});

test('paces at DIN wire speed, drains the last packet, and keeps bytes identical', async () => {
  const bytes = update();
  const sent: number[] = [];
  let time = 0;
  let wireReady = 0;
  let complete = false;
  await sendFirmware(bytes, { signal: new AbortController().signal, now: () => time,
    wait: async ms => { time += ms; },
    send: packet => {
      assert.ok(time >= wireReady);
      wireReady = time + packet.length * 1000 / MIDI_BYTES_PER_SECOND;
      sent.push(...packet);
    }, progress: p => {
      if (p.sentBytes === bytes.length) { assert.ok(time >= wireReady); complete = true; }
    } });
  assert.deepEqual(Uint8Array.from(sent), bytes);
  assert.ok(Math.abs(time - bytes.length * 1000 / MIDI_BYTES_PER_SECOND) < 1e-9);
  assert.ok(complete);
});

test('late timers never cause catch-up bursts, early timers cannot overrun the wire', async () => {
  let time = 0;
  let ready = 0;
  let waits = 0;
  await sendFirmware(update(), { signal: new AbortController().signal, now: () => time,
    wait: async ms => { time += ++waits % 2 ? ms / 2 : ms + 500; },
    send: packet => { assert.ok(time >= ready); ready = time + packet.length * 1000 / MIDI_BYTES_PER_SECOND; } });
  assert.ok(waits >= 10);
});

test('cancellation and device errors stop without sending completion markers', async () => {
  const controller = new AbortController();
  let sends = 0;
  let time = 0;
  await assert.rejects(sendFirmware(update(), { signal: controller.signal, now: () => time,
    send: () => { sends++; }, wait: async ms => { time += ms; controller.abort(); } }), { name: 'AbortError' });
  assert.equal(sends, 1);
  sends = 0;
  await assert.rejects(sendFirmware(update(), { signal: new AbortController().signal,
    send: () => { sends++; throw new Error('Disconnected'); } }), /Disconnected/);
  assert.equal(sends, 1);
  await assert.rejects(sendFirmware(update(), { signal: controller.signal, send: () => { sends++; } }), { name: 'AbortError' });
  assert.equal(sends, 1);
});

test('source edits after validation cannot alter the bytes being sent', async () => {
  const bytes = update();
  const expected = bytes.slice();
  const sent: number[] = [];
  let time = 0;
  await sendFirmware(bytes, { signal: new AbortController().signal, now: () => time,
    wait: async ms => { time += ms; }, send: packet => { sent.push(...packet); bytes.fill(0); } });
  assert.deepEqual(Uint8Array.from(sent), expected);
});
