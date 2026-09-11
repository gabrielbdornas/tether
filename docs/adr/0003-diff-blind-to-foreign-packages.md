# 0003 - `ttr diff` is blind to foreign (AUR) package changes

## Status

Accepted and fixed.

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

Found and documented first, fixed as a distinct, deliberate step rather than
folded silently into the same session - the same "log the bug, come back to
it deliberately" pattern this project's history already follows
(`docs/adr/0001`'s handling of the `capture_symlink_entry()` exclude-list bug
is the precedent).

Fixed by mirroring the existing native-package logic: `cmd_diff()` now also
computes `pacman -Qqem | sort` into a second temp file and `comm -23`/
`comm -13`s it against `sort -u "$VAULT/packages/foreign.txt"`. The result is
printed as its own "AUR packages installed since the last backup" / "AUR
packages removed since the last backup" pair of sections, kept separate from
the native "Installed"/"Removed" ones rather than merged into them - an AUR
addition means a source build the next time this vault is applied elsewhere
(the same distinction `restore` already draws with its own AUR-specific
prompt and `--aur` flag), so it reads better called out on its own line than
folded anonymously into the native list. The "Nothing has changed" message
now also requires both AUR diffs to be empty, not just the native ones.

## Consequences

- Before this fix, `ttr diff`'s "Nothing has changed" output could not be
  trusted to mean nothing changed - it was only trustworthy for
  native-package changes. That window is now closed.
- No known impact on `ttr backup`, `ttr restore`, `ttr verify`, or
  `ttr status` - all of those either read `pacman -Qqem` directly
  (`capture_packages`) or read the already-written `foreign.txt` from a
  completed backup, neither of which went through `cmd_diff`'s comparison
  logic. Confirmed by reading every other `native.txt`/`foreign.txt`
  read site in `bin/ttr`: restore's `missing_native`/`missing_foreign`,
  `verify_list`, `cmd_status`, and `cmd_diff_stock`'s `mine_raw` all already
  handled both lists - `cmd_diff` was the one outlier.
- `tests/cases/05-aur.sh` had AUR coverage for capture and restore, but none
  for `ttr diff` - a new section (##12) was added there rather than a new
  file, reusing that case's existing AUR fixtures. It's a direct regression
  test for this bug: native matching the vault while AUR drifts must not
  read as "Nothing has changed", and an AUR add/remove must be named in its
  own section, not silently folded into or omitted from the native one.

## What's next

- Confirming `ttr backup` actually writes an AUR package into
  `packages/foreign.txt` on a real machine (the capture-path theory above is
  architecturally sound and matches the sandboxed test harness, but was
  never independently re-verified against a real `ttr backup` run on the
  machine where this bug was originally found) is left as a real-machine
  check per `docs/TESTING.md` §4, not something a sandboxed fix can confirm.
