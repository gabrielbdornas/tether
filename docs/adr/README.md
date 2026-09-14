# Architecture Decision Records

Each file here records one decision made while building `tether`: the
context that forced it, what was decided, and the consequences. See the
root [README.md](../../README.md) for how to actually use the tool.

| ADR | Decision |
| --- | --- |
| [0001](0001-vendor-ress-and-add-live-symlink-mode.md) | Vendor `btsouth/omarchy-resurrect` as the base; add a new live-symlink sync mode |
| [0002](0002-extract-to-standalone-repo-rename-to-tether.md) | Extract from `gabrielbdornas/dotfiles` into this standalone repo; full rename to `tether`/`ttr` |
| [0003](0003-diff-blind-to-foreign-packages.md) | Fix `ttr diff` blindness to AUR/foreign package changes - it only ever compared native packages |
| [0004](0004-compared-against-other-omarchy-sync-plugins.md) | Compared against the other Omarchy sync/backup plugins; kept this project's scope |
