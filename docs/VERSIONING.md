# Kitbasher firmware versions

Generated firmware uses **K.01**, independently of the source OS version:

- **K** identifies Kitbasher.
- **01** is the Kitbasher firmware revision, starting at 1.
- The source OS remains recorded separately, for example `x14` or `x20`.

Downloads are named `kitbasher-K.01-x14.syx`, `kitbasher-K.01-x20.syx`, etc.
The Download page and JSON build report show the Kitbasher identity as well as
the original base. Custom machine selections share a revision; the output hash
and embedded layout identify a particular build. A revision is not a claim of
hardware qualification.

Kitbasher is not affiliated with Elektron or MDX. Modified builds are not
official MDX releases and are not supported by its creator.

## On the instrument

For 1.63-lineage builds (including X.14 and DEV), the four-byte container tag
becomes `K01 `, which the standard startup screen formats as `K.01`. The same
tag is returned by the existing MIDI identity path. Custom DEV screens may
also show their own upstream development identifier.

X.20 also reads the four-byte container tag for its startup display, so that tag
becomes `K01 ` too. Its separate strings `X.20` and `OS X.20 B` are replaced at boot
with `K.01` and `OS K.01`. Changing only those strings leaves startup showing
the upstream version. The old beta suffix is removed and both strings stay
NUL terminated within their original storage. Its exact source-file hash and
offline recipe-anchor checks still apply.

No boot-block, machine-ID, kit, pattern or SysEx transport version changes are
needed. Layout restoration continues to use the embedded original base ID.
The MIDI-reported legacy tag changes, so clients that infer capabilities from
an `X14`/`DEV` string rather than querying them may need to recognize `K01 `.

## Releasing a revision

`engine/src/firmware_version.ts` is the single source for the code and revision.
Increment `REVISION` when releasing changes to generated firmware (including
bundled model code or defaults); UI-only changes do not need a bump. Update the
version regression expectations with it. Keep the `K` code and two digits;
after 99, revise and verify the display scheme rather than overflowing it.

Version-label tests run in CI with synthetic anchors. With locally owned
firmware, `MD_FIRMWARE_DIR` enables real-output tag, boot-list, layout and
unchanged-input checks. `KB_X20_OS` enables the independent decoded-X.20 anchor
check. These checks do not constitute a hardware boot test.
