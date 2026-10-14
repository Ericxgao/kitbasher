# Global FX order (X.14)

Open **GLOBAL → ROUTING → FX ORDER**. Up/down selects **DIST** or **SRR**;
left selects **PRE**, right selects **POST**. The position is relative to the
track filter. Changes take effect immediately on all tracks and are saved with
the active global slot. EXIT returns to the routing categories.

| DIST | SRR | Order after AM and EQ |
| --- | --- | --- |
| POST | POST | Filter → SRR → DIST (original/default) |
| PRE | POST | DIST → filter → SRR |
| POST | PRE | SRR → filter → DIST |
| PRE | PRE | SRR → DIST → filter |

Each stage runs once. When both effects are on the same side of the filter, SRR
stays before DIST. Custom drive models follow DIST's position. AM, EQ, the mixer,
output assignments, delay and reverb sends retain their existing positions.
This is a global sound setting; kits and parameter locks do not select the order.

The browser includes the menu in X.14 builds. The CLI includes it on X.14 too;
`--no-fx-order` omits it. Other base versions do not yet have this menu.

## Implementation

The native ROUTING category gains a fourth entry, using its existing eight-entry
capacity. Page 63 was unused. Native page dispatch, dialog chrome and EXIT are
retained; only the two-row body and its arrow handling are added. Labels and
values stay on one line, with values aligned on the right.

Bits 4 and 5 of the 178-byte global record's mechanical-settings byte encode
DIST-pre and SRR-pre. Zero preserves the original order. The panel command masks
with 3 and global export retains seven bits. Resolution bit 0 and Swap Speeds bit
6 are preserved. The native resolution editor is adapted to read only bit 0 and
retain the other bits; its replaced body can also coexist with the Swap Speeds
editor. Three unused routing-menu pointer slots hold the cursor, last sent mode
and DSP-ready flag; none becomes part of the stored global data.

The native parameter sender establishes that DSP1 is ready before any new host
transaction. A setting edit, global-slot application or completed global SysEx
import then sends only a changed active mode, using the native atomic Y-write
transaction. Importing an inactive slot leaves the sound unchanged. Startup global loading defers
the update until the first native parameter send. The sender preserves registers,
arguments and interrupt mask, and chains into the existing custom-drive sender.

DSP1 Y:$23f (the unused last word of track 0's parameter block) holds the global
mode. The dispatcher reads it once per track block. P:$146800 holds a 160-word
helper, separately from the custom-drive and recovery allocations. Four native
program words change: P:$135..$136 enter the dispatcher; $21f returns from the
filter; $26f returns from DIST, including custom drive bodies. The small SRR loop
is relocated with its DO endpoint and delayed state store. DIST receives its own
state pointers rather than depending on SRR running immediately before it.

The builder checks native anchors, menu capacity, unused page entries, loaded
memory overlaps, custom-drive placement, boot destinations, emitted ColdFire ISA,
and final image readback. The existing firmware input remains untouched.

## Reproducing qualification

No firmware or generated binaries are committed. After compiling the engine:

```text
node ci/fx-order-build.mjs <x14.bin> <output-directory>
python ci/fx_order_dsp_check.py <output-directory>/dsp-test.json <dsphost-plain.exe> <test-output-directory>
python ci/fx_order_probe.py --probe <mdEncoderPress.exe> --stock <stock-1.63.bin> --factory <factory.cache> --rom <output-directory>/public.bin --out <probe-output-directory>
```

The DSP interpreter compares original/default audio and all native per-track
state across 12 DIST/SRR pairs and 24 blocks each, checks all four orders, and
checks balanced calls with each bundled custom drive law. The native emulator
exercises the menu, immediate DSP changes, global-slot changes, active-global
SysEx import and audible output. It also verifies that the routing helper remains
intact after playback with all 16 tracks assigned to a custom-drive model.
These checks do not constitute a hardware flash or hardware timing qualification.
