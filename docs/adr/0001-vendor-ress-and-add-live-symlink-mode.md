# 0001 - Vendor `btsouth/omarchy-resurrect` as the base; add a live-symlink sync mode

## Status

Accepted. Verified end to end on a real Omarchy machine, including a
credential-leak bug found and fixed during that verification.

## Context

This project started as a personal dotfiles/machine-setup effort that had
independently built a narrower version of the same problem: reproducing a
machine's setup from scratch, with no package-manifest tracking, no
plugin-pinning, no encrypted secrets, and no resumable restore.
[`btsouth/omarchy-resurrect`](https://github.com/btsouth/omarchy-resurrect)
(MIT-licensed) turned out to already answer the bigger question - not "sync
some dotfiles" but "everything installed on one machine reproduces onto a
fresh one" - with real adversarial-input hardening already in place: a
documented CVE-class fix (an unvalidated `schemaVersion` reaching bash
arithmetic, exploitable via command substitution) and an explicit
hostile-vault/hostile-loadout test suite.

## Decision

Vendor that code wholesale (copied in, license retained - see
[LICENSE](../../LICENSE) and the root [README](../../README.md)'s credit),
rather than tracked as a git fork, and add one new capability on top: an
opt-in **live-symlink sync mode**. Paths listed in
`~/.config/tether/symlink` (same format as the existing `include` list) are
moved into the vault and replaced with a symlink on `ttr backup`, instead of
rsync-copied - so an edit on either side is immediately visible on the
other, no second `ttr backup` required, and a restore on another machine
gets the same live link. This is the actual reason this project exists as
something more than a snapshot/restore tool: keeping config identical
across multiple machines as you actively work on it, not just replaying a
point-in-time capture.

The divergence-safety behavior (a real, non-symlinked file reappearing with
different content on restore gets backed up, never silently discarded)
follows the same pattern the rest of the tool already used for its own
`*.tether-bak` convention.

Verified on a real Omarchy machine, not just the sandboxed test harness. That
pass found a real bug: the symlink-mode capture path moved a path's whole
directory into the vault via `mv`, without ever consulting the exclude list
the rsync-copied `include` path does - so a credential-shaped file (a live
OAuth token) got committed in plaintext to the vault's local git history.
Fixed by writing the merged exclude list out as the vault's own
`.gitignore` on every backup: a symlinked path's content has to physically
exist in the vault for the `$HOME` symlink to resolve to it, so "on disk,
never committed" is the guarantee that actually holds for this mode -
weaker than "never captured" (what an `include` entry gets), but it's what
the exclude list can actually promise without breaking the feature.
`tests/cases/17-symlink-mode.sh` covers the regression.

## Consequences

- A second, larger surface (the ~3300-line CLI plus QML panel) to keep
  working, in exchange for not re-deriving package-manifest tracking,
  plugin-pinning, encrypted secrets, resumable restore, and adversarial-input
  hardening from scratch.
- Live-symlink mode's security posture is intentionally weaker than the rest
  of the tool's capture model (on-disk-but-gitignored, not never-captured) -
  a tradeoff specific to that one opt-in mode, not the default behavior.
- Proving this out on a real machine, not just unit tests, is what cleared
  the way for this project to become a standalone, installable repo - see
  [0002](0002-extract-to-standalone-repo-rename-to-tether.md).
