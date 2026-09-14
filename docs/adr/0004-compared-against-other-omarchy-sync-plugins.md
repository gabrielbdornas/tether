# 0004 - Compared against the other Omarchy sync/backup plugins; kept this project's scope

## Status

Accepted.

## Context

Three other public Omarchy plugins solve some version of "keep a machine's
setup portable": `gladimdim/omarchy-config-sync-plugin`, `dupontbertrand/omasync`,
and `omarchy-QOL/syncshell`. Before continuing to invest in `tether`, it was
worth reading each one's full source (not just its README) and checking
whether any of them already covers what `tether` is for, so effort isn't
spent re-solving a problem someone else already shipped.

The three, read in full from their own repos:

- **omarchy-config-sync-plugin** - a Python backend (`scripts/config_sync.py`,
  ~4600 lines) plus a QML panel, doing two-way git sync (Apply/Publish) of a
  *fixed* config tree: Hyprland config, `omarchy/{shell.json,shell.toml,
  branding,extensions,hooks,agents,themes}/`, shell plugin trees, and a
  cherry-picked subset of `~/.local/bin`. The sync scope is enumerated by a
  hardcoded inventory walker (`collect_inventory()`); its one user-extensible
  field (`machine_local` in a `.omarchy-config.json` marker) only *excludes*
  paths already inside that tree from auto-apply - it cannot register a new
  root. No package/AUR tracking. No secrets handling - the README tells users
  outright to keep secrets out of the synced tree.
- **omasync** - a bash core (`lib/core.sh` + `bin/omasync-*`) doing live
  device-to-device sync over SSH + rsync between paired laptops (LAN
  discovery, scrypt/HMAC pairing, a forced-command SSH entry point). Sync
  scope is a hardcoded four-item enum (`themes|shell|hyprland|plugins`),
  enforced identically on both the client's argument parser and the
  receiving side's `omasync_rsync_dest_allowed()` whitelist. Its own README
  says generalized app-config sync was *deliberately deferred*: "a stolen
  main key could otherwise mirror arbitrary app config paths onto every
  paired device." No package/AUR tracking. No secrets handling.
- **syncshell** - a Go native core plus QML panel that is a control surface
  *for Syncthing*, not a config-capture tool at all. Its Add Folder UI
  (`AddFolderForm.qml`) takes any existing directory with no scope
  restriction, so it is the only one of the three that could point at an
  arbitrary path (e.g. `~/.claude`) - but it inherits that generality from
  Syncthing itself, not from any dotfile/config-aware design. No package/AUR
  tracking, no capture/replay concept (it only ever continuously mirrors
  whatever folders are manually added to Syncthing), and no bespoke secrets
  handling beyond surfacing Syncthing's own untrusted-device encryption
  through its Web UI.

The features `tether` actually needs, per [0001](0001-vendor-ress-and-add-live-symlink-mode.md)
and [0002](0002-extract-to-standalone-repo-rename-to-tether.md) - the reason
this project exists rather than adopting an existing plugin:

1. Package manifest capture (native + AUR/foreign) and replay onto a fresh
   Omarchy install, not just config files.
2. A user-extensible arbitrary-path include list (`~/.config/tether/include`,
   merged with `defaults/include`), so a machine's actual working set - which
   is never fully enumerable in advance - can be captured, not just a
   maintainer-curated set of "known" Omarchy paths. `.claude` is a concrete
   example: nobody shipping a fixed inventory walker special-cased it, but a
   user with a generic include list needs zero code changes to add it.
3. Opt-in encrypted secrets, scanned for and never written to a report/log in
   cleartext.
4. Live-symlink mode for paths that should stay identical while actively
   worked on, without requiring a paired-device daemon or continuous P2P
   transport.
5. Adversarial-input hardening on every point where vault-sourced data
   reaches a shell command or file path (see README's Security section) -
   a baseline `tether` inherited from vendoring `btsouth/omarchy-resurrect`
   rather than one built from scratch.

## Decision

Keep `tether` as its own project rather than adopting or contributing this
scope into one of the three.

None of the three covers the combination above:

| | package/AUR capture + replay | arbitrary user-extensible include list | opt-in encrypted secrets | live/continuous mode | transport |
|---|---|---|---|---|---|
| **tether** | yes | yes (`include`/`exclude`/`symlink` lists) | yes | yes, opt-in per-path (live-symlink) | git (local vault, optionally pushed/pulled via any remote, e.g. GitHub) |
| omarchy-config-sync-plugin | no | no (fixed inventory tree; `machine_local` only excludes) | no (secrets explicitly kept out) | no (one-shot Apply/Publish, drift-polled) | git (user's own remote) |
| omasync | no | no (hardcoded 4-category enum, both ends) | no | themes only, via systemd+inotify | SSH + rsync, paired devices |
| syncshell | no (only installs Syncthing itself) | yes, but general-purpose (any dir via Syncthing), not config-aware | no (defers to Syncthing's own Web UI) | yes, inherent (it's a Syncthing frontend) | Syncthing P2P |

The two projects closest in spirit to `tether` (omarchy-config-sync-plugin,
omasync) both hit the same fork in the road - whether to let users name
arbitrary sync paths - and both deliberately chose *not to*, for reasons
that make sense in their own architectures: omasync's is a documented
security tradeoff (a compromised key syncing arbitrary paths to every paired
device over live SSH access), and omarchy-config-sync-plugin's inventory
walker is scoped to what it can safely reason about for two-way merge/apply
semantics. `tether`'s include-list model carries the same class of risk (an
untrusted vault entry can still only be *replayed*, never used to escalate
past what `ttr restore`'s existing path/remote/symlink validation already
gates - see README's Security section) but the tradeoff was already made and
tested via the vendored `omarchy-resurrect` hardening in
[0001](0001-vendor-ress-and-add-live-symlink-mode.md), rather than something
this decision has to re-litigate from zero.

syncshell answers a different question entirely (continuous folder mirroring
via Syncthing) and is the only one of the three general enough to sync
`~/.claude` - but adopting it in place of `tether` would mean giving up
package/AUR capture, fresh-install replay, and encrypted secrets entirely,
and taking on a standing Syncthing daemon and P2P pairing flow as the cost of
that generality.

## Consequences

- No code or design changed as a result of this comparison - it's a
  confirmation that `tether`'s scope is not redundant with existing plugins,
  not a decision to backport anything from them.
- The README's Install section now says explicitly that the vault's git
  remote (e.g. a private GitHub repo) is what makes `tether` work *across*
  machines, not only what makes a backup durable - the comparison surfaced
  that this was underspecified as a single, up-front sentence even though
  the individual pieces (`ttr init --remote`, `--push`, `restore --from`)
  were each already documented.
- If a future user specifically wants continuous, no-git, arbitrary-folder
  mirroring (syncshell's actual use case) alongside `tether`'s capture/replay
  model, the two are not mutually exclusive - nothing about `tether`'s vault
  conflicts with also running syncshell for that narrower purpose.
