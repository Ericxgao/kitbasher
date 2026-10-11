# SMP time-stretch machines

Author: hcar on Elektronauts / murdenihcam on GitHub.

These three original SysEx releases form the SMP family in the catalog. Their bytes, machine IDs, version 0.6, controls, logos and declared cycle budgets are preserved.

| Machine | Sample bank | Hardware |
| --- | --- | --- |
| SMP-ST | UW ROM 1–48 and internal E12 samples 49–69 | UW required |
| SMP-SR | UW ROM 1–48 | UW required |
| SMP-S2 | Internal E12 samples 1–21 | UW or non-UW |

Original discussion and author compatibility notes: [Custom USR Machines for X.20](https://www.elektronauts.com/t/custom-usr-machines-for-x-20/257233).

Pinned release: [murdenihcam-usr-machines, commit b3c7474](https://github.com/murdenihcam/murdenihcam-usr-machines/tree/b3c74740f0e8fa7309dd02e85c3b0ec1631ad7d2/SMP_Stretch). The `_source` folder contains the assembly, definitions, shared engine and build/test tooling. Catalog entries link to the corresponding source wrappers and pin each downloaded SysEx by SHA-256.

No license was specified in the pinned repository or supplied release; these files retain the author's attribution and are not relabeled under Kitbasher's license. The author reports hardware testing on a UW+ MKII. Kitbasher validates packaging, checksums and declared admission metadata; it has not independently measured or hardware-tested these machines.

The source repository describes SMP-SL, but no downloadable slicer package was present at the pinned commit. Only the three available time-stretch releases are included.
