# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Repository purpose

`tether` is an Omarchy plugin: capture a machine's packages, dotfiles,
Omarchy config, web apps, shell plugins, and (opt-in, encrypted) secrets
into a git-backed vault, and replay that vault onto a fresh Omarchy install
in seconds. It also supports an opt-in **live-symlink mode** for paths that
should stay identical across machines as you actively work on them, not
just snapshotted.

It started life vendored inside a personal dotfiles monorepo under the name
`ress` (itself based on upstream's `btsouth/omarchy-resurrect`, MIT-licensed
— see [LICENSE](LICENSE)), then was extracted here as a standalone,
publicly installable repo and fully renamed. `docs/adr/` is the source of
truth for *why* — read `docs/adr/README.md` for the index before assuming
why something is built a certain way, especially [0001](docs/adr/0001-vendor-ress-and-add-live-symlink-mode.md)
(the vendoring + live-symlink decision) and [0002](docs/adr/0002-extract-to-standalone-repo-rename-to-tether.md)
(the extraction/rename).

## Architecture

- **`bin/ttr`** — the whole engine, one bash file (~3300 lines), no QML
  dependency. Runs from a TTY on a machine with no desktop. Sections, in
  order: capture, secret scan, manifest read/write, backup, restore, AUR
  handling, status, settings, verify, share/apply (loadouts), usage, and the
  subcommand dispatch table at the bottom. `set -euo pipefail` throughout.
- **`Panel.qml`** / **`Service.qml`** / **`Model.js`** — the Quickshell bar
  widget, a thin face over `bin/ttr`: every button is one CLI subcommand run
  with `--porcelain` (a line protocol on stdout — `STEP|`, `PROGRESS|`,
  `LOG|`, `DONE|` — never prose). `Model.js` is a `.pragma library`, plain
  JS with no QML API, testable directly under node. Two `Service.qml`
  instances exist at runtime (one the panel owns, one the shell mounts
  headless for scheduled backups) and must not diverge from `bin/ttr`'s own
  path constants — QML can't ask the CLI for them, so config/state/vault
  paths are duplicated by hand in both places.
- **`manifest.json`** — the Omarchy plugin manifest: id (`gabrielbdornas.tether`),
  aliases, the bar-widget/service entry points. The plugin id is meant to
  stay fixed once real users exist (Omarchy's marketplace keys its registry
  on it) — see ADR 0002 for why it was still safe to change during the
  extraction.
- **`defaults/`** — the shipped default `include`/`exclude`/`symlink`/`aur-deny`
  lists, merged with the user's own `~/.config/tether/{include,exclude,symlink,aur-deny}`
  via `merged_list()` in `bin/ttr`. `defaults/exclude.txt` carries the
  credential-pattern exclusions (`*.key`, `*.pem`, `hosts.yml`, etc.) — this
  file is a real security boundary, not just documentation, so changes to it
  need the same care as changes to `bin/ttr` itself.

## Testing

No compiled artifact — this is a shell CLI plus QML. Four layers, cheapest
first; `docs/TESTING.md` covers the full strategy including the real-tools
checks and the six things only a clean VM can prove.

1. **`./tests/run.sh`** (`./tests/run.sh <filter>` to run matching cases only)
   — the main suite. Each of the 17 cases in `tests/cases/` runs against a
   throwaway `$HOME` with fake `pacman`/`yay`/`sudo`/`systemctl`/`curl`/`git`/`omarchy`
   on `PATH` (`tests/bin/`), driven through `tests/lib/harness.sh`'s `ttr`/`ttr_answer`/`ttr_tty`
   wrapper functions (`TTR="$REPO_DIR/bin/ttr"`). Nothing outside the
   sandbox is read or written; the fake `sudo` has no real privileges, so a
   case can assert a restore *did not* do something.
2. **`./tests/mutate.sh`** (~12 minutes) — mutation testing: breaks one
   behavior at a time in a throwaway copy and checks the suite notices. A
   `SURVIVED` line is a feature the suite only appears to cover. Run it when
   changing what the tests are *for*, not on every edit.
3. **`tests/cases/16-qml.sh`** — `qmllint` with Omarchy/Quickshell imports
   resolved, plus a check `qmllint` can't do on its own: every
   `engine.<member>` referenced in `Panel.qml` is checked against what
   `Service.qml` actually declares, since a bad binding there renders blank
   with no error anywhere.
4. **Real-machine checks** (docs/TESTING.md §4) — round-trip capture/verify
   against this machine's real state, a real restore into a scratch `$HOME`
   with the live desktop shadowed out, and the AUR-name annotation (the one
   thing the fake `curl` can't stand in for). Not run by CI; run by hand
   before a release.

Always `bash -n bin/ttr` before anything else — a parse error otherwise
fails every case in the same confusing way, which `tests/run.sh` already
checks first on your behalf.

## Working conventions

- Every subcommand that shells out to `pacman`/`yay`/`git`/`systemctl` with
  data read from a vault gets a `--` end-of-options boundary — a name from
  an untrusted vault must never be able to arrive as an option. See the
  README's Security section for the full validation posture (this code was
  hardened against a documented CVE-class bug and a hostile-vault/hostile-loadout
  test suite; keep new vault-reading code to the same standard).
- The vault's exclude list is a real security boundary for the rsync-copied
  `include` path (paths matching it are never captured), but a *weaker*
  guarantee for live-symlink-mode paths (matching content still has to
  exist on disk in the vault for the symlink to resolve — it's kept out of
  the vault's git history via a generated `.gitignore`, not out of the
  vault's working tree). Don't conflate the two when touching capture code.
- `--porcelain` output is a protocol, not prose — anything added there needs
  a stable `TYPE|`-prefixed line shape, not a human-readable sentence.
- No secret is ever written to a report, a log line, or stdout in cleartext
  — `report_secret_findings()`'s pattern (name the file, never quote the
  match) is the one to follow for anything similar.
- This repo's own history intentionally starts mid-project (see ADR 0002) —
  don't assume `git log` here is the full story; the dotfiles repo it was
  extracted from, and its own ADR history, is the earlier context.
