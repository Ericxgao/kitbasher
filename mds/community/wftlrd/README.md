# K55 machines

Eight original SysEx files supplied by the user in `K55_wftlrd (3).zip`. Attribution to wftlrd comes from the archive filename; no source URL, license or qualification notes were supplied. No license from this repository is imposed on these files.

The K55 family contains BD, SD, TM, CG, RS, CB, HH and CY. CG is version 0.8; the other seven are version 0.7. The complete family uses 12,158 DSP words and 41,088 package bytes across eight slots, within an otherwise empty X.20 bank.

Files are preserved byte-for-byte, including controls, logos, cycle declarations and inherited descriptor IDs. BD/TM share `org.spsx.usr.tx9-bd`; SD/CG share `org.spsx.usr.tx9-sd`; RS/HH/CY share `org.spsx.usr.tx9-rs`; CB retains `org.spsx.usr.tx8-cb`. Each entry explicitly records its shared ID exception. Their aliases and content hashes are distinct; the browser uses content hashes for selection and protocol readback, so these variants remain separate releases alongside the core machines.

Packaging, checksums and declared admission metadata are validated. Kitbasher has not independently benchmarked or hardware-tested these releases. The archive's `__MACOSX` metadata files are excluded.
