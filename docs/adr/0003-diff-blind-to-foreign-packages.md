# 0003 - `ttr diff` is blind to foreign (AUR) package changes

## Status

Proposed (bug confirmed on a real machine, not yet fixed)

## Context

Testing whether a newly-installed package would actually get picked up by
`tether`'s package capture: `infisical-bin` (AUR-only, installed via
`yay -S infisical-bin`) was installed on a machine with one existing vault
backup. Before running `ttr backup` again, `ttr diff` was run first to
preview what changed.

Confirmed state at the time:

- `pacman -Qo "$(command -v infisical)"` → owned by `infisical-bin`.
- `pacman -Qqem | grep infisical` → `infisical-bin` (explicitly installed,
  foreign/AUR - correctly classified).
- `pacman -Qi infisical-bin` → `Install Reason: Explicitly installed`.
- The vault's `packages/foreign.txt` was empty (0 bytes) from the prior
  backup, taken before `infisical-bin` was installed.

Despite that, `ttr diff` printed:

```
Nothing has changed since the last backup.
Try `ttr diff --stock` to see how far this machine is from a fresh Omarchy.
```

### Root cause

`cmd_diff()` in `bin/ttr` (around line 2715) only ever compares **native**
packages:

```bash
pacman -Qqen | sort >"$now"
if [[ -f $VAULT/packages/native.txt ]]; then
  added=$(comm -23 "$now" <(sort -u "$VAULT/packages/native.txt") || true)
  removed=$(comm -13 "$now" <(sort -u "$VAULT/packages/native.txt") || true)
fi
```

There is no equivalent `pacman -Qqem` vs `$VAULT/packages/foreign.txt`
comparison anywhere in the function. Any AUR/foreign package installed or
removed since the last backup is therefore invisible to `ttr diff`,
regardless of how the rest of the tool classifies it.

This is a `cmd_diff`-only bug. `capture_packages()` (the function `ttr
backup` actually uses) re-runs both `pacman -Qqen` *and* `pacman -Qqem`
fresh on every call, so the real capture path is not known to share this
blind spot - `ttr backup` should still write a correct `foreign.txt`. That
part of the theory is not yet independently verified against a real
`ttr backup` run on this machine; see "What's next" below.

## Decision

Not fixed yet - this ADR exists to record the finding before moving on, per
the same "log the bug, come back to it deliberately" pattern this project's
history already follows (`docs/adr/0001`'s handling of the
`capture_symlink_entry()` exclude-list bug is the precedent: found on a real
machine, documented, fixed as a distinct, deliberate step rather than
folded silently into the same session).

The fix, once picked up, is expected to mirror the existing native-package
logic: compute `pacman -Qqem | sort` into a second temp file, `comm -23`/
`comm -13` it against `sort -u "$VAULT/packages/foreign.txt"` the same way,
and fold the result into the same "Installed since the last backup" /
"Removed since the last backup" sections (or a clearly separate foreign-
package section, if mixing native and AUR names in one list reads as
confusing) - a design call for whoever implements it, not decided here.

## Consequences

- Until fixed, `ttr diff`'s "Nothing has changed" output cannot be trusted
  to mean nothing changed - it can only be trusted for native-package
  changes. Anyone relying on `ttr diff` before a `ttr backup` to decide
  whether a backup is worth running should not skip the backup on AUR-only
  changes just because `diff` reported nothing.
- No known impact on `ttr backup`, `ttr restore`, `ttr verify`, or
  `ttr status` - all of those either read `pacman -Qqem` directly
  (`capture_packages`) or read the already-written `foreign.txt` from a
  completed backup, neither of which goes through `cmd_diff`'s comparison
  logic.
- `tests/cases/05-aur.sh` already exists and covers AUR packages in some
  capacity (capture and/or restore) - worth checking, when this is fixed,
  whether it already would have caught this or whether `cmd_diff`
  specifically has no coverage and a new case/assertion is needed.

## What's next

- Confirm `ttr backup` actually writes `infisical-bin` into
  `packages/foreign.txt` on the real machine where this was found (the
  capture-path theory above is architecturally sound - `capture_packages`
  reads live `pacman -Qqem` unconditionally - but hasn't been confirmed by
  an actual backup run yet).
- Implement the `cmd_diff` fix described above.
- Check `tests/cases/05-aur.sh` for existing `ttr diff` coverage before
  deciding whether a new test case is needed vs. extending that one.
