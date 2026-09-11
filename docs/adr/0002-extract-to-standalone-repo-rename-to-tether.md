# 0002 - Extract to a standalone repo; rename `ress`/`resurrect` to `tether`/`ttr`

## Status

Accepted and done.

## Context

The code in [0001](0001-vendor-ress-and-add-live-symlink-mode.md) was
originally developed inside a personal dotfiles monorepo
(`gabrielbdornas/dotfiles`), under a working name inherited from upstream:
`ress` (itself short for upstream's original name, `resurrect`). Two
problems with leaving it there once real-machine verification passed and
installability was actually considered:

- **Installability.** `omarchy plugin add <url>` clones a repo wholesale and
  reads `manifest.json` at its root. The code's manifest lived at a
  subdirectory path inside the dotfiles monorepo, not at that repo's root,
  so installing straight from it would have dragged unrelated personal
  bootstrap scripts and ADR history into every install alongside the plugin
  itself.
- **Naming.** "ress"/"resurrect" frames the tool as one-time machine
  migration. The live-symlink mode added in 0001 makes continuous
  cross-machine sync the actual point - work/home machine config drift was
  the concrete motivating problem. Renaming before any real user or vault
  depended on the old name was free; waiting would have made it a breaking
  change, the same way upstream's own `tsouth89.resurrect` plugin id never
  got renamed even after that project settled on the name `ress`.

## Decision

`git subtree split` used on the dotfiles monorepo to preserve this code's
own commit history with its subdirectory prefix stripped, pushed here as a
new, standalone, public repo - `github.com/gabrielbdornas/tether`.

Full rename landed immediately after, before this repo had any real users:

- Binary `bin/ress` -> `bin/ttr` (the real command, not an alias - `tether`
  is the project/plugin name only). Plugin id `gabrielbdornas.ress` ->
  `gabrielbdornas.tether`. Config/state/vault directories, the vault
  manifest filename and backup suffix (`ress.json`/`.ress-bak` ->
  `tether.json`/`.tether-bak`), and the internal `ressVersion` vault-manifest
  field (-> `tetherVersion`) all moved with it.
- `Panel.qml`'s `moduleName`/`ipcTarget` - which, it turned out, still named
  the *original* upstream id `tsouth89.resurrect` even after the earlier
  rename to `gabrielbdornas.ress` - were corrected to match the manifest for
  the first time.
- No legacy aliases or compat shims kept for the old names anywhere: a
  pre-launch rename with zero real users and no existing vault to migrate.
  The two `*_LEGACY` constants already in the code - for reading a vault
  written under upstream's own pre-`ress` name - were removed outright
  rather than extended with a third legacy tier; they predated this
  decision and encoded upstream's own resurrect-to-ress rename, not this
  one.
- `ress.sh` (the loadout-sharing short-link redirector) was left exactly as
  it is - a real third-party domain this tool depends on functionally, not
  this project's own name, so renaming it would just break the feature.
  Only the internal variable holding that string moved
  (`RESS_HOST` -> `SHARE_HOST`); the domain itself did not.
- Everywhere else that named "ress"/"resurrect" as this project's own
  identity - in code, comments, docs, and shipped default lists - was
  removed and replaced. The exception is license compliance: `LICENSE`
  stays verbatim (the actual legal requirement, "Copyright (c) 2026 Tyler
  South"), and the root [README](../../README.md)'s License section carries
  a single credit line back to the upstream project this is based on.

The former host repo (`gabrielbdornas/dotfiles`) stays fully decoupled from
this one: no bootstrap-script wiring added there. It installs the same way
any other Omarchy plugin does, by hand, via `omarchy plugin add`.

## Consequences

- This repo's own git history starts as what looks like a vendor dump (the
  subtree-split commits, predating the rename) - expected, since full
  upstream history was never vendored in the first place, only the two
  commits that touched this code inside the dotfiles monorepo.
- No backward compatibility with any vault or install created under the
  `ress`/`resurrect` names. Accepted: this is a clean-break rename, not a
  compatibility one, and nothing real depended on the old names yet.
- This repo now owns its own release cadence, test suite, and maintenance
  burden independently of the dotfiles repo it was extracted from.
