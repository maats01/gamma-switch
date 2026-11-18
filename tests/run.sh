#!/usr/bin/env bash
# Runner de testes do gamma-switch. Uso: bash tests/run.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAMMA="$ROOT/bin/gamma"

VALUES=(0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5)

setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/ICC" "$TMP/stubs" "$TMP/state"
  for v in "${VALUES[@]}"; do : > "$TMP/ICC/sRGB-${v}G.icc"; done
  cat > "$TMP/stubs/kscreen-doctor" <<EOF
#!/usr/bin/env bash
[[ -n "\${KS_SLEEP:-}" ]] && sleep "0.0\$((RANDOM % 4))"
echo "\$*" >> "$TMP/ks.log"
exit \${KS_RC:-0}
EOF
  for s in qdbus6 notify-send; do
    cat > "$TMP/stubs/$s" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$TMP/osd.log"
EOF
  done
  chmod +x "$TMP/stubs/"*
  : > "$TMP/ks.log"; : > "$TMP/osd.log"
  export PATH="$TMP/stubs:$ORIG_PATH"
  export GAMMA_ICC_DIR="$TMP/ICC"
  export XDG_STATE_HOME="$TMP/state"
  unset GAMMA_OUTPUT KS_RC KS_SLEEP
}

teardown() { rm -rf "$TMP"; }

fail() { echo "  $*" >&2; return 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "esperado '$2', obtido '$1'"; }
last_ks() { tail -n1 "$TMP/ks.log"; }
g() { "$GAMMA" "$@"; }

# ---- testes ----

test_first_toggle_applies_default() {
  g toggle || fail "rc!=0" || return 1
  assert_eq "$(last_ks)" "output.DP-1.iccprofile.$GAMMA_ICC_DIR/sRGB-0.7G.icc" || return 1
  assert_eq "$(g status)" "on 0.7" || return 1
  grep -q "Gamma 0.7" "$TMP/osd.log" || fail "OSD sem 'Gamma 0.7'"
}

test_toggle_twice_turns_off() {
  g toggle && g toggle || fail "rc!=0" || return 1
  assert_eq "$(last_ks)" "output.DP-1.iccprofile." || return 1
  assert_eq "$(g status)" "off 0.7" || return 1
  grep -q "Gamma normal" "$TMP/osd.log" || fail "OSD sem 'Gamma normal'"
}

test_up_from_off_turns_on() {
  g up || fail "rc!=0" || return 1
  assert_eq "$(g status)" "on 0.75" || return 1
  [[ "$(last_ks)" == *"/sRGB-0.75G.icc" ]] || fail "ks: $(last_ks)"
}

test_down_then_toggle_remembers() {
  g down; g down; g toggle; g toggle
  [[ "$(last_ks)" == *"/sRGB-0.6G.icc" ]] || fail "ks: $(last_ks)"
}

test_full_range_names() {
  g reset
  for _ in $(seq 16); do g down; done
  assert_eq "$(g status)" "on 0.5" || return 1
  : > "$TMP/ks.log"
  for _ in $(seq 20); do g up; done
  local got expected=""
  got="$(sed -E 's|.*/sRGB-(.*)\.icc$|\1|' "$TMP/ks.log" | tr '\n' ' ')"
  for v in "${VALUES[@]:1}"; do expected+="${v}G "; done
  assert_eq "$got" "$expected" || return 1
  g up
  assert_eq "$(g status)" "on 1.5"
}

test_clamp_low() {
  for _ in $(seq 10); do g down || fail "rc!=0" || return 1; done
  assert_eq "$(g status)" "on 0.5"
}

test_reset() {
  g up; g up; g reset || fail "rc!=0" || return 1
  assert_eq "$(last_ks)" "output.DP-1.iccprofile." || return 1
  assert_eq "$(g status)" "off 0.7"
}

test_corrupt_state() {
  mkdir -p "$XDG_STATE_HOME/gamma-switch"
  echo lixo > "$XDG_STATE_HOME/gamma-switch/state"
  local out; out="$(g status)" || fail "rc!=0" || return 1
  assert_eq "$out" "off 0.7"
}

test_missing_profile() {
  rm "$GAMMA_ICC_DIR/sRGB-0.7G.icc"
  local rc=0; g toggle 2> "$TMP/err" || rc=$?
  assert_eq "$rc" "1" || return 1
  [[ -s "$TMP/err" ]] || fail "stderr vazio" || return 1
  [[ ! -s "$TMP/ks.log" ]] || fail "kscreen-doctor chamado" || return 1
  assert_eq "$(g status)" "off 0.7"
}

test_kscreen_failure() {
  local rc=0; KS_RC=1 g toggle 2>/dev/null || rc=$?
  assert_eq "$rc" "1" || return 1
  assert_eq "$(g status)" "off 0.7"
}

test_bad_usage() {
  local rc=0; g foo 2> "$TMP/err" || rc=$?
  assert_eq "$rc" "2" || return 1
  grep -q "uso:" "$TMP/err" || fail "stderr sem 'uso:'"
}

test_invalid_last_line_state() {
  mkdir -p "$XDG_STATE_HOME/gamma-switch"
  printf 'value=70\non=2\n' > "$XDG_STATE_HOME/gamma-switch/state"
  local out; out="$(g status)" || fail "rc!=0 (on=2)" || return 1
  assert_eq "$out" "off 0.7" || return 1
  printf 'on=1\nvalue=abc\n' > "$XDG_STATE_HOME/gamma-switch/state"
  out="$(g status)" || fail "rc!=0 (value=abc)" || return 1
  assert_eq "$out" "on 0.7"
}

test_crlf_state_does_not_break() {
  mkdir -p "$XDG_STATE_HOME/gamma-switch"
  printf 'value=75\r\non=1\r\n' > "$XDG_STATE_HOME/gamma-switch/state"
  g toggle || fail "rc!=0"
}

test_parallel_up_serialized() {
  export KS_SLEEP=1
  local i; for i in 1 2 3 4 5 6; do g up & done; wait
  assert_eq "$(g status)" "on 1.0" || return 1
  [[ "$(last_ks)" == *"/sRGB-1.0G.icc" ]] || fail "ks: $(last_ks)"
}

test_default_icc_dir_is_repo_via_symlink() {
  unset GAMMA_ICC_DIR
  ln -s "$GAMMA" "$TMP/stubs/gamma"
  "$TMP/stubs/gamma" toggle || fail "rc!=0" || return 1
  assert_eq "$(last_ks)" "output.DP-1.iccprofile.$ROOT/icc/sRGB-0.7G.icc"
}

test_bundled_profiles_complete() {
  local v; for v in "${VALUES[@]}"; do
    [[ -s "$ROOT/icc/sRGB-${v}G.icc" ]] || fail "faltando sRGB-${v}G.icc" || return 1
  done
}

test_kscreen_failure_shows_osd() {
  KS_RC=1 g toggle 2>/dev/null
  grep -q "falha" "$TMP/osd.log" || fail "OSD sem aviso de falha"
}

test_missing_profile_shows_osd() {
  rm "$GAMMA_ICC_DIR/sRGB-0.7G.icc"
  g toggle 2>/dev/null
  grep -q "perfil não encontrado" "$TMP/osd.log" || fail "OSD sem erro de perfil"
}

# ---- runner ----
ORIG_PATH="$PATH"
pass=0; failn=0
for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  setup
  if ( $t ) > "$TMP/out" 2>&1; then
    echo "PASS $t"; pass=$((pass+1))
  else
    echo "FAIL $t"; sed 's/^/    /' "$TMP/out" | tail -5; failn=$((failn+1))
  fi
  teardown
done
echo "$pass passed, $failn failed"
[[ $failn -eq 0 ]]
