# The live-symlink mode: a path on ~/.config/ress/symlink is linked into the
# vault instead of rsync-copied, so an edit on either side is visible on the
# other without running `ress backup` again — and a restore recreates the
# same link, backing up (never discarding) a real file that diverged.

seed_machine
mkdir -p "$HOME/.config/ress"
printf '.claude\n' >"$HOME/.config/ress/symlink"
mkdir -p "$HOME/.claude"
printf '{"model":"test"}\n' >"$HOME/.claude/settings.json"

ress init
assert_ok "ress init"

VAULT="$XDG_DATA_HOME/ress/vault"

ress backup -m "first"
assert_ok "ress backup"

assert_file "$VAULT/home/.claude/settings.json" "vault holds .claude's captured content"
assert_file_contains "$VAULT/home/.claude/settings.json" "test"

if [[ -L $HOME/.claude ]]; then _pass; else _fail ".claude is a symlink after backup"; fi
if [[ $(readlink -f "$HOME/.claude") == "$(readlink -f "$VAULT/home/.claude")" ]]; then
  _pass
else
  _fail ".claude resolves to the vault's copy"
fi

# Edit through the symlink — no second `ress backup` needed for the vault to
# see it, because $HOME/.claude and $VAULT/home/.claude are now the same tree.
printf 'edited-through-the-link\n' >"$HOME/.claude/note.txt"
assert_file "$VAULT/home/.claude/note.txt" "an edit through the live symlink lands directly in the vault"

# Simulate a fresh machine: drop the link (the underlying vault tree, and this
# machine's config/vault pointer, stay put — same as a real second box pointed
# at the same vault).
rm -f "$HOME/.claude"

ress restore --only config --yes
assert_ok "ress restore --only config"

if [[ -L $HOME/.claude ]]; then _pass; else _fail ".claude is a symlink after restore"; fi
assert_file_contains "$HOME/.claude/settings.json" "test" "restore recreates the link back to the vault's content"

# Divergence safety: a real (non-symlinked) file reappears with different
# content — restore must back it up, never silently discard it.
rm -f "$HOME/.claude"
mkdir -p "$HOME/.claude"
printf '{"model":"diverged"}\n' >"$HOME/.claude/settings.json"

ress restore --only config --restart --yes
assert_ok "ress restore --only config (diverged)"
assert_file "$HOME/.claude.ress-bak/settings.json" "the diverged directory is backed up, not discarded"
assert_file_contains "$HOME/.claude.ress-bak/settings.json" "diverged"
if [[ -L $HOME/.claude ]]; then _pass; else _fail ".claude is relinked to the vault after the diverged restore"; fi
assert_file_contains "$HOME/.claude/settings.json" "\"test\"" "the vault's version wins after the diverged restore"
