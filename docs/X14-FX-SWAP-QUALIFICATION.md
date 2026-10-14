# X.14 public FX ORDER + SWAP SPEEDS candidate

Owner-requested combined hardware candidate, 2026-10-14. The implementation PRs
remain separate; branch `build/x14-fx-order-swap-speeds` combines them for testing.
The build includes all 25 bundled public machines, UW support, clean recovery,
FX ORDER, and SWAP SPEEDS for the eight data encoders and dedicated LEVEL knob.

- BIN SHA-256: `2b186c9347895800f02cf445070af751ca541e7d3c6f078509554939186a7876`
- SysEx SHA-256: `b01504b05478a5a186dd16085df9d28734d2966a9b4f1fa26ae2379db181dd01`
- SysEx: `Kitbasher-X14-FX-Order-Swap-Speeds.syx`, 1,767,658 bytes / 15,785 messages.
- Local artifacts: lab `build/x14-public-fx-swap-20261014/`; firmware stays out of git.

Build with the CLI from X.14 using `--catalog catalog --uw --clean-recovery
--encoder-settings`, writing `candidate.bin`, `candidate.engine.json` with
`--report`, and `candidate.json` with `--gate-report`. Encode the BIN's OS
container with `encodeSyx(containerOf(image))`; the CLI keeps the input format.
Run `ci/fx-order-release.mjs <stock-x14.bin> <update.syx>` for exact image,
hook, DSP, canonical packet, boot-destination and ISA readback verification.

Validation on the exact candidate:

- All 29 build gates and `npm run check` passed.
- Independent Python `tools/make_syx.py` decoding matches the BIN's OS container;
  checksums, contiguous addresses and the OS-only end message pass.
- `ci/fx_order_probe.py`: native menu, all four modes, global-slot restoration,
  active-global SysEx import, audible output, and unchanged helper after playback
  with all 16 tracks assigned to VAD BD.
- Lab `tools/encoder_speed_check.py`: 200 checks passed, including both
  directions, press/release, all nine knobs, and simultaneous switch presses.

Transfer and device acceptance are separate results. Hardware boot and playback
remain unconfirmed until the owner reports them. The local `release.json` and
`flash.log` record transfer status.

## UM-ONE transfer, 2026-10-14

After the owner confirmed receiver readiness with "go", the exact SysEx above
was sent to **UM-ONE 1**, paced at MIDI wire speed with 0 ms additional gap.
All 15,785 messages / 1,767,658 bytes completed in **590 seconds**, sender exit 0.
The local `flash-receipt.json` records the file hash, timestamps and log hash.
This confirms transmission only; device acceptance, restart and hardware
playback remain pending owner observation.
