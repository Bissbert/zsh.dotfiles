#!/bin/sh
# Run the installer, the bug check and the measurement tools in a Linux
# container, and print everything the documentation quotes.
#
#   sh tools/linux-run.sh > docs/captures/linux-run.txt
#
# The repository is mounted read-only and cloned inside the container, so the
# run uses the committed files. The installer, apt and chsh only touch the
# container. The JSON results are copied back into tools/.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
IMAGE=python:3.12-slim-bookworm

docker run --rm -v "$repo:/repo:ro" -v "$out:/out" "$IMAGE" bash -c '
set -u
section() { printf "\n=== %s\n" "$1"; }
levels() { grep -E "^\[(INFO|WARN|ERROR|HINT)\]" "$1"; }

apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq zsh git curl ca-certificates >/dev/null 2>&1
git config --global --add safe.directory "*"
git clone -q /repo /work/zsh.dotfiles
cd /work/zsh.dotfiles

section "environment"
uname -srm
. /etc/os-release; echo "$PRETTY_NAME"
zsh --version
bash --version | head -1
python3 --version
echo "repo HEAD: $(git log -1 --format="%h %s")"

section "syntax checks"
bash -n install_zsh.sh; echo "bash -n install_zsh.sh exit=$?"
zsh -n profiles/classic/zshrc; echo "zsh -n profiles/classic/zshrc exit=$?"
zsh -n profiles/pure/zshrc; echo "zsh -n profiles/pure/zshrc exit=$?"
bash install_zsh.sh --help; echo "--help exit=$?"

section "bug 1: exported ZSH points at another Oh My Zsh checkout"
git clone -q --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /opt/other-omz
h=/home/bug1; mkdir -p "$h"
ZSH=/opt/other-omz HOME="$h" ZDOTDIR="$h" SHELL="$(command -v zsh)" \
  bash install_zsh.sh --link >/tmp/bug1.log 2>&1
echo "install exit=$?"
echo "lines with \"folder already exists\": $(grep -c "folder already exists" /tmp/bug1.log)"
echo "Oh My Zsh in the target home: $(test -d "$h/.oh-my-zsh/.git" && echo yes || echo no)"
echo "themes added to the exported checkout: $(ls /opt/other-omz/custom/themes | grep -cv example)"

section "full install: classic profile, --link"
h=/home/classic; mkdir -p "$h"
HOME="$h" SHELL=/bin/bash bash install_zsh.sh --link >/tmp/classic.log 2>&1
echo "install exit=$?"
levels /tmp/classic.log | grep -v "Installing font\|Installing plugin"
echo "fonts downloaded: $(ls "$h/.local/share/fonts" | wc -l)"
echo "plugins cloned: $(ls "$h/.oh-my-zsh/custom/plugins" | grep -cv example)"
for f in .zshrc .p10k.zsh; do printf "%s -> %s\n" "$f" "$(readlink "$h/$f")"; done
echo "fastfetch logo: $(test -f "$h/.config/fastfetch/logo.txt" && echo present)"
for c in autojump direnv sqlite3 pygmentize; do printf "%-11s %s\n" "$c" "$(command -v "$c" || echo missing)"; done
echo "fastfetch   $("$h/.local/bin/fastfetch" --version 2>&1 | head -1)"
echo "root login shell: $(getent passwd root | cut -d: -f7)"
echo "--- install_manifest.txt"
sed "s/^timestamp=.*/timestamp=<run time>/" "$h"/.zsh-backups/*/install_manifest.txt
echo "--- zsh -i -c exit with the deployed profile"
HOME="$h" zsh -i -c "echo \"ZSH=\$ZSH theme=\$ZSH_THEME\"" </dev/null 2>/tmp/classic.err
echo "exit=$? stderr lines=$(wc -l </tmp/classic.err)"
head -5 /tmp/classic.err

section "re-run over the classic install (update path)"
sleep 1
HOME="$h" SHELL="$(command -v zsh)" bash install_zsh.sh --link >/tmp/rerun.log 2>&1
echo "install exit=$?"
levels /tmp/rerun.log | grep -E "already present|Updating plugin|Setting up|default shell|Backups" | sort | uniq -c
echo "backup directories: $(ls "$h/.zsh-backups" | wc -l)"
echo "files in the newest backup: $(ls "$h/.zsh-backups/$(ls "$h/.zsh-backups" | tail -1)" | tr "\n" " ")"

section "full install: pure profile, --copy"
h=/home/pure; mkdir -p "$h"
HOME="$h" SHELL="$(command -v zsh)" bash install_zsh.sh --profile pure --copy >/tmp/pure.log 2>&1
echo "install exit=$?"
levels /tmp/pure.log | grep -E "p10k|default shell|ERROR|WARN"
echo "last log line: $(tail -1 /tmp/pure.log)"
echo "\"Installation complete\" printed: $(grep -c "Installation complete" /tmp/pure.log)"
echo "install_manifest.txt files: $(ls "$h"/.zsh-backups/*/install_manifest.txt 2>/dev/null | wc -l)"
echo "--- trace of the last function"
HOME=/home/pure-trace SHELL="$(command -v zsh)" \
  bash -x install_zsh.sh --profile pure --copy 2>&1 | grep -E "^\++ " | tail -3
echo ".zshrc: $(test -L "$h/.zshrc" && echo symlink || echo regular file)"
echo ".p10k.zsh: $(test -e "$h/.p10k.zsh" && echo present || echo absent)"
HOME="$h" zsh -i -c "echo \"ZSH=\$ZSH\"" </dev/null 2>/tmp/pure.err
echo "zsh -i -c exit=$? stderr lines=$(wc -l </tmp/pure.err)"

section "startup benchmark (tools/bench_startup.py --reps 9)"
python3 tools/bench_startup.py --reps 9 --out /out/results_startup.json 2>/tmp/bench.err
echo "exit=$?"
grep -v "^round\|^sandbox\|^cloning\|^  " /tmp/bench.err | head -5

section "shell inventory, classic (tools/inventory.py)"
python3 tools/inventory.py --profile classic --out /out/results_inventory.json 2>/tmp/inv.err
echo "exit=$?"

section "shell inventory, pure (tools/inventory.py)"
python3 tools/inventory.py --profile pure --out /out/results_inventory_pure.json 2>/tmp/invp.err
echo "exit=$?"
'

cp "$out"/results_startup.json "$out"/results_inventory.json \
  "$out"/results_inventory_pure.json "$repo/tools/"
rm -rf "$out"
