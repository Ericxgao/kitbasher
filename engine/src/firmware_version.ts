// Kitbasher's release identity is independent of the source OS and model selection.
// Bump REVISION for released changes to generated firmware; see docs/VERSIONING.md.
import { u32 } from './bytes.js';

const CODE = 'K';
const REVISION = 1;
const number = String(REVISION).padStart(2, '0');
if (number.length !== 2) throw new Error('Firmware revision no longer fits the display: revise the version scheme');
export const FIRMWARE_VERSION = Object.freeze({ name: 'Kitbasher', code: CODE, revision: REVISION, display: `${CODE}.${number}` });
export type FirmwareVersion = typeof FIRMWARE_VERSION;

// Legacy boot screen inserts a dot after tag[0]; MIDI identity returns these four bytes.
export const FIRMWARE_TAG = `${CODE}${number} `;
export const firmwareTagBytes = (): Uint8Array => new TextEncoder().encode(FIRMWARE_TAG);

/** The tag after the three packed slots, including X.20's stage and two placeholder slots.
 * Do not parse/decompress the data slots: X.20 uses a different layout after this tag. */
export function stampContainerVersion(container: Uint8Array, expected: string): number {
  let at = 0;
  for (let n = 0; n < 3; n++) {
    if (at + 8 > container.length) throw new Error('Firmware version: truncated slot header');
    const size = u32(container, at);
    if (!size || at + 8 + size > container.length) throw new Error('Firmware version: invalid slot length');
    at += 8 + size;
  }
  const tag = String.fromCharCode(...container.subarray(at, at + 4));
  if (expected.length !== 4 || tag !== expected) throw new Error(`Firmware version: expected tag ${JSON.stringify(expected)}, got ${JSON.stringify(tag)}`);
  container.set(firmwareTagBytes(), at);
  return at;
}

export const firmwareFilename = (base: string): string =>
  `kitbasher-${FIRMWARE_VERSION.display}-${base.replace(/[^a-zA-Z0-9._-]/g, '-')}.syx`;

// X.20 has separate four-character and nine-character, NUL-terminated display strings.
// Recipe sites use data words, so the ISA gate does not interpret these labels as instructions.
const short = new TextEncoder().encode(FIRMWARE_VERSION.display);
const full = new Uint8Array(10);
full.set(new TextEncoder().encode(`OS ${FIRMWARE_VERSION.display}`));
export const VERSION_WORDS: Readonly<Record<string, number>> = Object.freeze({
  VERSION_SHORT: u32(short, 0), VERSION_FULL_0: u32(full, 0), VERSION_FULL_1: u32(full, 4),
  VERSION_FULL_2: (full[8] << 8) | full[9],
});
