[← back to the overview](../README.md)

# Bugs found during the documentation pass

> **Since this pass:** an independent adjudication confirmed the entry below,
> and a subsequent fix pass applied it to the default branch in commit
> `3627c9e`. `install_oh_my_zsh` now passes `ZSH="${target}"` to the upstream
> bootstrap alongside `RUNZSH`, `CHSH` and `KEEP_ZSHRC`, so the bootstrap
> installs to the same directory the installer uses for detection and updates.
> Read the reproduction below as the state at the time of the pass, not as the
> current state of the default branch.

## Oh My Zsh bootstrap inherits an unrelated `ZSH` variable

**File and lines:** `install_zsh.sh:135-136`

**What happens:** When the target Oh My Zsh directory does not exist, the
installer invokes the upstream bootstrap through `sh -c` without setting or
clearing `ZSH`. An exported `ZSH` from the caller can therefore make the
bootstrap choose a different directory. In the isolated run for this pass, the
temporary `HOME` was ignored by the bootstrap, which reported that the real
`/Users/fabian/.oh-my-zsh` directory already existed and exited non-zero.

**How to reproduce:** From this checkout, use an exported `ZSH` that points to
an existing Oh My Zsh checkout, and a temporary home whose `.oh-my-zsh` path is
absent:

```sh
tmp_home=$(mktemp -d)
ZSH="$HOME/.oh-my-zsh" \
HOME="$tmp_home" ZDOTDIR="$tmp_home" SHELL="$(command -v zsh)" \
  bash install_zsh.sh --link
```
The observed output includes:

```text
The $ZSH folder already exists (/Users/fabian/.oh-my-zsh).
[ERROR] Oh My Zsh installation failed.
```

**Fix I would have made:** pass the installer’s target directory to the
upstream bootstrap explicitly. This documentation pass does not apply the
change.

```diff
diff --git a/install_zsh.sh b/install_zsh.sh
--- a/install_zsh.sh
+++ b/install_zsh.sh
@@
-    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
+    ZSH="${target}" RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
       sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || \
```
