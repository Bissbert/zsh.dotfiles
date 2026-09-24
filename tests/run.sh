#!/usr/bin/env bash
# Offline test suite for install_zsh.sh and the profiles.
#
#   bash tests/run.sh            # all tests
#   bash tests/run.sh pure       # only tests whose name contains "pure"
#
# Every test runs the installer in a fresh temporary HOME. curl, git clone and
# pull, chsh, apt-get and sudo are replaced by the stubs in tests/stubs, so no
# network access is needed and nothing outside the temporary directory changes.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STUBS="${ROOT}/tests/stubs"
TOOLS="${ROOT}/tests/tools"
REAL_GIT="$(command -v git)"
export REAL_GIT

PASS=0
FAIL=0
FAILED=()
CURRENT=''

fail() {
  printf '    FAIL: %s\n' "$1"
  CURRENT_FAILED=1
}

assert_eq() {  # expected actual message
  [[ "$1" == "$2" ]] || fail "$3: expected [$1], got [$2]"
}

assert_file() { [[ -f "$1" && ! -L "$1" ]] || fail "expected regular file $1"; }
assert_link() {  # path target
  [[ -L "$1" ]] || { fail "expected symlink $1"; return; }
  assert_eq "$2" "$(readlink "$1")" "symlink target of $1"
}
assert_absent() { [[ ! -e "$1" && ! -L "$1" ]] || fail "expected $1 to be absent"; }
assert_contains() {  # file pattern message
  grep -qE -- "$2" "$1" || fail "$3 (no match for /$2/ in $(basename "$1"))"
}
assert_not_contains() {
  if grep -qE -- "$2" "$1"; then fail "$3 (unexpected /$2/ in $(basename "$1"))"; fi
}

# Run the installer in the current sandbox. Sets STATUS; output goes to $OUT.
install() {
  env -i \
    HOME="$T_HOME" PATH="${T_PATH}" STUB_LOG="$T/stub.log" REAL_GIT="$REAL_GIT" \
    SHELL="${T_SHELL}" TERM=dumb ${T_ENV[@]+"${T_ENV[@]}"} \
    bash "${ROOT}/install_zsh.sh" "$@" >"$OUT" 2>&1
  STATUS=$?
}

manifest() { ls "$T_HOME"/.zsh-backups/*/install_manifest.txt 2>/dev/null | tail -1; }

run_test() {
  local name="$1"
  [[ -n "${FILTER:-}" && "$name" != *"$FILTER"* ]] && return
  T="$(mktemp -d)"
  T_HOME="$T/home"
  mkdir -p "$T_HOME"
  T_PATH="${STUBS}:${TOOLS}:/usr/local/bin:/usr/bin:/bin"
  T_SHELL=/bin/bash
  T_ENV=()
  OUT="$T/out.log"
  : >"$T/stub.log"
  CURRENT_FAILED=0
  printf '%s\n' "$name"
  "$name"
  if ((CURRENT_FAILED)); then
    FAIL=$((FAIL + 1))
    FAILED+=("$name")
    sed 's/^/      | /' "$OUT" | tail -15
  else
    PASS=$((PASS + 1))
  fi
  rm -rf "$T"
}

# --- argument handling -------------------------------------------------------

test_help_exits_zero() {
  install --help
  assert_eq 0 "$STATUS" "--help exit status"
  assert_contains "$OUT" '^Usage: install_zsh.sh' "usage text"
  assert_eq 0 "$(wc -l <"$T/stub.log")" "no external calls for --help"
}

test_unknown_argument_is_rejected() {
  install --bogus
  assert_eq 1 "$STATUS" "exit status"
  assert_contains "$OUT" "Unknown argument\(s\): --bogus" "error message"
}

test_missing_profile_is_rejected() {
  install --profile nope
  assert_eq 1 "$STATUS" "exit status"
  assert_contains "$OUT" "Profile 'nope' not found" "error message"
}

test_profile_equals_form_is_accepted() {
  install --profile=pure --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_contains "$(manifest)" '^profile=pure$' "manifest profile"
}

test_missing_required_command_is_reported() {
  # A PATH without zsh: build it from symlinks to everything else we need.
  local bin="$T/bin" c
  mkdir -p "$bin"
  for c in bash env curl git tar find date mkdir dirname cat; do
    ln -s "$(PATH="${STUBS}:$PATH" command -v "$c")" "$bin/$c"
  done
  T_PATH="$bin"
  install --copy
  assert_eq 1 "$STATUS" "exit status"
  assert_contains "$OUT" "Required command 'zsh' is not available" "error message"
}

# --- classic profile ---------------------------------------------------------

test_classic_copy_deploys_files_and_manifest() {
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_file "$T_HOME/.zshrc"
  assert_file "$T_HOME/.p10k.zsh"
  cmp -s "$T_HOME/.zshrc" "$ROOT/profiles/classic/zshrc" || fail ".zshrc differs from template"
  assert_file "$T_HOME/.config/fastfetch/logo.txt"
  assert_contains "$T_HOME/.config/fastfetch/config.jsonc" '"type": "file"' "fastfetch config"
  local m; m="$(manifest)"
  [[ -n "$m" ]] || { fail "no install_manifest.txt"; return; }
  assert_contains "$m" '^mode=copy$' "manifest mode"
  assert_contains "$m" '^profile=classic$' "manifest profile"
  assert_contains "$m" "^git_commit=$("$REAL_GIT" -C "$ROOT" rev-parse HEAD)$" "manifest commit"
  assert_contains "$OUT" 'Installation complete' "completion message"
}

test_classic_link_creates_symlinks() {
  install --link
  assert_eq 0 "$STATUS" "exit status"
  assert_link "$T_HOME/.zshrc" "$ROOT/profiles/classic/zshrc"
  assert_link "$T_HOME/.p10k.zsh" "$ROOT/profiles/classic/p10k.zsh"
  assert_contains "$(manifest)" '^mode=link$' "manifest mode"
}

test_external_checkouts_are_cloned() {
  install --copy
  local p
  assert_file "$T_HOME/.oh-my-zsh/oh-my-zsh.sh"
  for p in themes/powerlevel10k themes/pure plugins/zsh-autosuggestions \
      plugins/zsh-completions plugins/zsh-syntax-highlighting \
      plugins/fast-syntax-highlighting plugins/zsh-histdb plugins/fzf-tab; do
    [[ -d "$T_HOME/.oh-my-zsh/custom/$p/.git" ]] || fail "missing checkout $p"
  done
  assert_eq 8 "$(grep -c '^git clone --depth=1' "$T/stub.log")" "clone count"
}

test_fonts_are_downloaded() {
  install --copy
  assert_eq 4 "$(ls "$T_HOME/.local/share/fonts" | wc -l | tr -d ' ')" "font files"
  assert_contains "$T/stub.log" 'MesloLGS%20NF%20Bold%20Italic.ttf' "escaped font URL"
}

test_zdotdir_is_honoured_for_zshrc() {
  T_ENV=(ZDOTDIR="$T/zdot")
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_file "$T/zdot/.zshrc"
  assert_absent "$T_HOME/.zshrc"
}

# --- re-run and backups ------------------------------------------------------

test_rerun_updates_and_backs_up() {
  install --copy
  printf '# my edit\n' >>"$T_HOME/.zshrc"
  sleep 1
  : >"$T/stub.log"
  install --link
  assert_eq 0 "$STATUS" "second run exit status"
  assert_contains "$OUT" 'Oh My Zsh already present. Updating' "update path"
  assert_eq 0 "$(grep -c '^git clone' "$T/stub.log")" "no clones on re-run"
  assert_eq 9 "$(grep -c 'pull --ff-only' "$T/stub.log")" "pull count"
  assert_eq 2 "$(ls "$T_HOME/.zsh-backups" | wc -l | tr -d ' ')" "backup directories"
  local newest; newest="$T_HOME/.zsh-backups/$(ls "$T_HOME/.zsh-backups" | tail -1)"
  assert_contains "$newest/.zshrc" '^# my edit$' "edited .zshrc backed up"
  assert_link "$T_HOME/.zshrc" "$ROOT/profiles/classic/zshrc"
}

test_failed_update_aborts() {
  install --copy
  T_ENV=(STUB_PULL_STATUS=1)
  install --copy
  assert_eq 1 "$STATUS" "exit status"
  assert_contains "$OUT" 'Failed to update Oh My Zsh' "error message"
}

test_existing_ascii_fastfetch_config_is_replaced() {
  mkdir -p "$T_HOME/.config/fastfetch"
  printf '{ "logo": { "type": "ascii" } }\n' >"$T_HOME/.config/fastfetch/config.jsonc"
  printf 'old logo\n' >"$T_HOME/.config/fastfetch/logo.txt"
  install --copy
  assert_contains "$T_HOME/.config/fastfetch/config.jsonc" '"type": "file"' "config rewritten"
  assert_contains "$(dirname "$(manifest)")/logo.txt" '^old logo$' "old logo backed up"
}

test_existing_custom_fastfetch_config_is_kept() {
  mkdir -p "$T_HOME/.config/fastfetch"
  printf '{ "logo": { "type": "builtin" } }\n' >"$T_HOME/.config/fastfetch/config.jsonc"
  install --copy
  assert_contains "$T_HOME/.config/fastfetch/config.jsonc" '"builtin"' "config kept"
}

# --- pure profile (issue #5) -------------------------------------------------

test_pure_install_completes() {
  install --profile pure --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_contains "$OUT" 'Installation complete' "completion message"
  local m; m="$(manifest)"
  [[ -n "$m" ]] || { fail "no install_manifest.txt"; return; }
  assert_contains "$m" '^profile=pure$' "manifest profile"
}

test_pure_install_changes_default_shell() {
  install --profile pure --link
  assert_contains "$T/stub.log" "^chsh -s $(command -v zsh)$" "chsh call"
  assert_contains "$OUT" 'Default shell changed' "log line"
}

test_pure_install_writes_no_p10k_or_logo() {
  install --profile pure --copy
  assert_file "$T_HOME/.zshrc"
  cmp -s "$T_HOME/.zshrc" "$ROOT/profiles/pure/zshrc" || fail ".zshrc differs from template"
  assert_absent "$T_HOME/.p10k.zsh"
  assert_absent "$T_HOME/.config/fastfetch/logo.txt"
}

test_pure_keeps_existing_p10k() {
  printf '# mine\n' >"$T_HOME/.p10k.zsh"
  install --profile pure --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_contains "$T_HOME/.p10k.zsh" '^# mine$' ".p10k.zsh untouched"
  assert_contains "$OUT" 'existing file left in place' "log line"
}

# --- Oh My Zsh bootstrap (fixed in 3627c9e) ----------------------------------

test_exported_zsh_does_not_redirect_bootstrap() {
  mkdir -p "$T/other-omz"
  T_ENV=(ZSH="$T/other-omz")
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_file "$T_HOME/.oh-my-zsh/oh-my-zsh.sh"
  assert_absent "$T/other-omz/oh-my-zsh.sh"
  assert_not_contains "$OUT" 'folder already exists' "bootstrap message"
}

# --- default shell -----------------------------------------------------------

test_default_shell_already_zsh() {
  T_SHELL="$(command -v zsh)"
  install --copy
  assert_contains "$OUT" 'Zsh is already the default shell' "log line"
  assert_not_contains "$T/stub.log" '^chsh' "no chsh call"
}

test_chsh_failure_is_a_warning() {
  T_ENV=(STUB_CHSH_STATUS=1)
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_contains "$OUT" 'Unable to change default shell' "warning"
}

# --- optional tools ----------------------------------------------------------

test_missing_tools_are_installed_with_apt() {
  T_PATH="${STUBS}:/usr/local/bin:/usr/bin:/bin"
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  local pkg
  for pkg in autojump direnv sqlite3 python3-pygments; do
    assert_contains "$T/stub.log" "apt-get install -y ${pkg}$" "apt install ${pkg}"
  done
}

test_failed_apt_install_is_a_warning() {
  T_PATH="${STUBS}:/usr/local/bin:/usr/bin:/bin"
  T_ENV=(STUB_APT_STATUS=100)
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_contains "$OUT" 'WARN.*Failed to install autojump' "warning"
}

test_fastfetch_download_failure_is_a_warning() {
  T_PATH="${STUBS}:/usr/local/bin:/usr/bin:/bin"
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  assert_contains "$OUT" 'Failed to download fastfetch' "warning"
}

test_fastfetch_release_is_installed() {
  T_PATH="${STUBS}:/usr/local/bin:/usr/bin:/bin"
  T_ENV=(STUB_FASTFETCH=ok)
  install --copy
  assert_eq 0 "$STATUS" "exit status"
  [[ -x "$T_HOME/.local/bin/fastfetch" ]] || fail "fastfetch not installed"
}

# --- profiles ----------------------------------------------------------------

test_profiles_parse() {
  local p
  for p in "$ROOT"/profiles/*/zshrc; do
    zsh -n "$p" 2>"$T/err" || fail "zsh -n $p: $(cat "$T/err")"
  done
  bash -n "$ROOT/install_zsh.sh" || fail "bash -n install_zsh.sh"
}

test_deployed_profiles_start() {
  local p
  for p in classic pure; do
    rm -rf "$T_HOME"; mkdir -p "$T_HOME"
    install --profile "$p" --copy
    HOME="$T_HOME" TERM=dumb zsh -i -c 'print -r -- "ZSH=$ZSH"' </dev/null >"$T/zsh.out" 2>"$T/zsh.err"
    assert_eq 0 "$?" "$p: zsh -i exit status"
    assert_contains "$T/zsh.out" "^ZSH=$T_HOME/.oh-my-zsh$" "$p: ZSH"
  done
}

FILTER="${1:-}"
for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  run_test "$t"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0)) || { printf 'failed: %s\n' "${FAILED[*]}"; exit 1; }
