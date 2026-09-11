# The vault manifest is tether.json.

seed_machine
ttr init >/dev/null
VAULT="$XDG_DATA_HOME/tether/vault"

ttr backup -m first
assert_ok "backup"
assert_file "$VAULT/tether.json" "manifest is written as tether.json"
assert_equals "$(jq -r '.tetherVersion' "$VAULT/tether.json")" "1.2.0" "manifest records the tether version"

# ---- the backup suffix -----------------------------------------------------

printf 'replaced by the restore\n' >"$HOME/.bashrc"
ttr restore --yes --only config
assert_ok "restore config"
assert_file "$HOME/.bashrc.tether-bak" "a replaced file is kept under the backup suffix"
assert_file_contains "$HOME/.bashrc.tether-bak" "replaced by the restore"
assert_file_contains "$HOME/.bashrc" "alias ll" "the vault's copy is in place"

# The suffix is never captured back into the vault.
ttr backup -m second >/dev/null
assert_no_file "$VAULT/home/.bashrc.tether-bak" "the backup suffix is excluded from capture"
