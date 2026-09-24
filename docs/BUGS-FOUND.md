[← back to the overview](../README.md)

# Bugs found

Both bugs are fixed. The second turned up when the installer was run end to end
in a Linux container (see [How this was measured](measurement.md)). Each has a
regression test in [`tests/run.sh`](../tests/run.sh).

| # | Entry | Status |
|---|---|---|
| 1 | Oh My Zsh bootstrap inherits an unrelated `ZSH` variable | Fixed in [`3627c9e`](https://github.com/Bissbert/zsh.dotfiles/commit/3627c9e) |
| 2 | The Pure install exits 1 before the default shell and manifest steps | Fixed in [`8bce836`](https://github.com/Bissbert/zsh.dotfiles/commit/8bce836) |

The checks below run inside the container that
[`tools/linux-run.sh`](../tools/linux-run.sh) sets up (`python:3.12-slim-bookworm`,
Debian 12, Zsh 5.9, GNU bash 5.2.15), as root, from a `git clone` of the
repository.

```mermaid
flowchart TD
    A["install_zsh.sh"] --> B["install_oh_my_zsh<br/>ZSH=target (entry 1, fixed)"]
    B --> C["themes, plugins, tools, fonts"]
    C --> D["install_p10k_config<br/>install_zshrc"]
    D --> E{"profile has<br/>fastfetch_logo.txt?"}
    E -->|classic: yes| F["ensure_default_shell<br/>write_manifest"]
    E -->|pure: no| G["return 0<br/>(entry 2, fixed)"]
    G --> F

    style B fill:#238636,stroke:#3fb950,color:#fff
    style F fill:#238636,stroke:#3fb950,color:#fff
    style G fill:#238636,stroke:#3fb950,color:#fff
```

## 1. Oh My Zsh bootstrap inherits an unrelated `ZSH` variable

**Status:** fixed in [`3627c9e`](https://github.com/Bissbert/zsh.dotfiles/commit/3627c9e).

**File:** `install_zsh.sh` (`install_oh_my_zsh`)

**What happened:** when the target Oh My Zsh directory did not exist, the
installer ran the upstream bootstrap without setting `ZSH`. An exported `ZSH`
from the caller made the bootstrap use that directory instead of the target in
`HOME`. With `ZSH` pointing at an existing checkout, the bootstrap reported
`The $ZSH folder already exists` and the installer stopped with
`[ERROR] Oh My Zsh installation failed.`

**What changed:** the bootstrap is started with `ZSH="${target}"` alongside
`RUNZSH`, `CHSH` and `KEEP_ZSHRC`, so it installs to the directory the
installer uses for detection and updates. A deliberately exported alternative
location is no longer used for a fresh install.

**Check:** `ZSH` points at a separate existing Oh My Zsh clone, and `HOME` is
empty:

```sh
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /opt/other-omz
ZSH=/opt/other-omz HOME=/home/bug1 ZDOTDIR=/home/bug1 SHELL="$(command -v zsh)" \
  bash install_zsh.sh --link
```

```
install exit=0
lines with "folder already exists": 0
Oh My Zsh in the target home: yes
themes added to the exported checkout: 0
```

## 2. The Pure install exits 1 before the default shell and manifest steps

**Status:** fixed in [`8bce836`](https://github.com/Bissbert/zsh.dotfiles/commit/8bce836) ([#5](https://github.com/Bissbert/zsh.dotfiles/issues/5)).

**File:** `install_zsh.sh:365` (`install_fastfetch_logo`)

**What happened:** `install_fastfetch_logo` started with
`[[ -f "${template}" ]] || return`. The Pure profile has no
`fastfetch_logo.txt`, so the test failed and `return` passed on its status 1.
The script runs with `set -e`, so it stopped there. `.zshrc` had already been
deployed and the shell started, but `ensure_default_shell` and `write_manifest`
never ran, no "Installation complete" line was printed, and the exit status was
1. Output before the fix:

```sh
HOME=/home/pure SHELL="$(command -v zsh)" bash install_zsh.sh --profile pure --copy
```

```
install exit=1
last log line: [INFO] No Powerlevel10k configuration for this profile; skipping.
"Installation complete" printed: 0
install_manifest.txt files: 0
--- trace of the last function
+ template=/work/zsh.dotfiles/profiles/pure/fastfetch_logo.txt
+ [[ -f /work/zsh.dotfiles/profiles/pure/fastfetch_logo.txt ]]
+ return
```

Without the manifest, the backup directory did not record which profile and
commit were deployed, and a caller that checked the exit status saw a failure.

**What changed:** the guard is `[[ -f "${template}" ]] || return 0`, so a
profile without a logo skips the step and the install continues.

**Check:** `test_pure_install_completes`, `test_pure_install_changes_default_shell`
and `test_pure_keeps_existing_p10k` in [`tests/run.sh`](../tests/run.sh) fail
with the old `return` and pass with the fix. The Linux run now shows:

```
install exit=0
"Installation complete" printed: 1
install_manifest.txt files: 1
mode=copy
profile=pure
```

Entry 1 is covered by `test_exported_zsh_does_not_redirect_bootstrap`.
