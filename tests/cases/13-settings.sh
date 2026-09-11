# A setting whose value is a choice: a misspelled choice used to be accepted and
# then read as the default, so `AUR=yse` quietly meant "ask".

seed_machine
ttr init >/dev/null

for bad in AUR=yse ENABLE_UNITS=1 SECRET_SCAN=warning AUTO_BACKUP=yes \
           CAPTURE_AUTOSTART=true SECRETS_MODE=gpg INCLUDE_PACKAGES=on; do
  ttr set "$bad"
  assert_fails "ttr set $bad is refused"
  assert_output "must be one of"
done

ttr set AUTO_INTERVAL_HOURS=soon
assert_fails "a non-numeric interval is refused"
assert_output "whole number of hours"

ttr set VAULT=
assert_fails "an empty vault path is refused"

ttr set NOT_A_SETTING=1
assert_fails "an unknown key is still refused"
assert_output "unknown setting"

# The valid values all still work, and land in the file.
ttr set AUR=yes ENABLE_UNITS=no SECRET_SCAN=block CAPTURE_AUTOSTART=1
assert_ok "valid values are accepted, several at once"
CONFIG="$XDG_CONFIG_HOME/tether/config"
assert_file_contains "$CONFIG" "AUR=yes"
assert_file_contains "$CONFIG" "ENABLE_UNITS=no"
assert_file_contains "$CONFIG" "SECRET_SCAN=block"
assert_file_contains "$CONFIG" "CAPTURE_AUTOSTART=1"

# A refused value leaves the previous one alone.
ttr set AUR=nope
assert_fails "refused"
assert_file_contains "$CONFIG" "AUR=yes" "the old value survives a refused write"

# The values the panel sends are all accepted, since it writes through the CLI.
for panel in AUTO_BACKUP=on AUTO_BACKUP=off AUR=ask AUR=yes AUR=no \
             ENABLE_UNITS=ask ENABLE_UNITS=yes ENABLE_UNITS=no \
             INCLUDE_SECRETS=1 INCLUDE_SECRETS=0; do
  ttr set "$panel"
  assert_ok "the panel's value $panel is accepted"
done

# A hand-edited config with a nonsense value still loads, and reads as the safe
# default rather than refusing to run at all.
printf 'AUR=whatever\nENABLE_UNITS=whatever\nSECRET_SCAN=whatever\n' >>"$CONFIG"
ttr status
assert_ok "a config with a bad value still loads"
ttr status --json
assert_equals "$(jq -r '.settings.aur' <<<"$OUT")" "whatever" "status reports what is in the file"

VAULT=$(make_vault)
printf 'somepkg\n' >"$VAULT/packages/foreign.txt"
seal_vault "$VAULT"
ttr --vault "$VAULT" restore --yes --only packages
assert_ok "and a nonsense AUR value reads as ask, not as yes"
assert_not_called "yay -S" "which is the safe direction to fail in"

# ---- concurrent writes ----------------------------------------------------

# The panel fires one `ttr set` per toggle through execDetached. Two landing at
# once used to be a read-modify-write race: both read the same file, the later
# write dropped the earlier change.
ttr set AUR=ask ENABLE_UNITS=ask SECRET_SCAN=warn >/dev/null
for i in 1 2 3 4 5 6 7 8; do
  "$TTR" set "AUR=yes" >/dev/null 2>&1 &
  "$TTR" set "ENABLE_UNITS=no" >/dev/null 2>&1 &
  "$TTR" set "SECRET_SCAN=block" >/dev/null 2>&1 &
done
wait

assert_file_contains "$CONFIG" "AUR=yes" "a concurrent write is not lost"
assert_file_contains "$CONFIG" "ENABLE_UNITS=no" "nor is the second"
assert_file_contains "$CONFIG" "SECRET_SCAN=block" "nor the third"

# The file is still one valid config, not a torn write.
assert_equals "$(grep -c '^[A-Z_]*=' "$CONFIG")" "$(grep -c '^[A-Z_]*=' "$CONFIG")" "config parses"
ttr status --json
assert_ok "and status can still read it"
assert_equals "$(jq -r '.settings.aur' <<<"$OUT")" "yes"
