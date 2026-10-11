# MDS machine library

The MDS page installs individual user machines into an X.20 Machine Bank. It is separate from Kitbasher's firmware builder. `catalog.json` is the curated public index; the website build validates each package and publishes content-addressed files. Capacity, controls, version and identity come from the package itself.

The first collection contains the X.20 USR releases in `core/` (TX8, TX9, TXZ, SYN, P-I and NFX) and the Simple606-inspired community TR6 port in `tr6/`. Core binaries are preserved byte-for-byte from the supplied X.20 USR collection. Their source and license were not supplied; the catalog records that rather than inventing a source link or license. The site repository's license does not override individual machine licenses. TR6 source attribution and its MIT notice are in each assembly file.

## Curating releases

1. Add a reviewed `.syx` or `.mds` containing **one machine** under `mds/`. Keep author attribution and any required license text alongside it. Do not add full firmware dumps.
2. Add an entry to `catalog.json` with `file`, its file `sha256`, `channel` (`core` or `community`), `author`, `summary`, `source` (HTTPS URL or null), `project`, `license`, and optional `notes`. Pin source links to the release commit when possible. Use notes for control changes that affect saved kits.
3. For an update, replace the entry for that stable machine ID with the reviewed release and update the SHA-256 pin. The build rejects duplicate IDs, changed hashes, malformed packages, and declarations outside the X.20 admission budget. Hash validation does not establish that DSP code is safe; review and qualify the machine separately.
4. Run `node ci/workflow.mjs check`. Review the generated MDS page, parameter descriptions, capacities and source links before merging. A site deployment publishes the updated catalog.

Users can import local `.mds` or `.syx` files without publishing them. A local bank SysEx may contain multiple machine transfers. Non-MDS SysEx is rejected. Downloads rewrite only the destination slot, transaction and wire checksums; package bytes and their identities remain unchanged.

## MIDI installation

Use Chrome on HTTPS or localhost and grant MIDI SysEx access. Both MIDI directions are required: interface OUT → Machinedrum IN, and Machinedrum OUT → interface IN. Select the destination Machine Bank **on the device**. Connect MIDI at the bottom of the bank preview; the browser reads the bank automatically when the ports are selected. Missing ports or missing device replies produce an error before any machine data is sent. The protocol does not select or identify banks by a persistent bank ID. Keep that bank selected throughout installation.

The browser reads slots and capabilities, accounts for untouched slots and replacement deltas, and finds an installation order that fits at every commit. It does not erase slots. Reordering the selection changes its USR destinations; it does not rewrite category-menu metadata. Kits reference slot model IDs, so replacing a slot can change the sound of existing kits.

Choose **Flash machines** to install directly from the sidebar preview. There is no separate review step. A fresh connection and bank check runs automatically before sending. If the bank changed since the preview, the browser updates it and stops so the user can check the new destinations before retrying. Each header/data/end message waits for its matching acknowledgment. WAIT extends the response window within a bounded overall deadline. Timeouts resend the identical message, including End of Dump if its final ACK was lost. A repairable CORRUPT NAK resends the requested packet once; terminal rejection stops the transfer. There is no open-loop fallback. A final committed ACK and a readback of the installed content ID, size and validity are required for success. Untouched slots are verified after each machine. A failed multi-machine operation can leave earlier successfully committed machines installed; retrying automatically checks the bank again.

“Stop after this machine” finishes the current transaction and stops before the next one. Disconnecting closes the ports. A browser-origin lock prevents two Kitbasher tabs from installing at once; other MIDI applications must be closed by the user.

Protocol reference: [MDS v1](https://github.com/jmamma/MDS/tree/main/docs).
