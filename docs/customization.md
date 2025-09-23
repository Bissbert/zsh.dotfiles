# Customization Guide

This guide covers common tweaks to the tracked Zsh configuration.

## Powerlevel10k Prompt
The template `profiles/classic/p10k.zsh` is based on the upstream classic preset with local overrides.

### Prompt Layout
- **Left prompt** (`POWERLEVEL9K_LEFT_PROMPT_ELEMENTS`): `dir`, `vcs`, `prompt_char`.
- **Right prompt** (`POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS`): status indicators, language/runtime segments, toolbox context, todo/time trackers, `battery`, and `time`.
- Add or remove segments by editing these arrays. A list of available segments is documented in the upstream README and in your installer logs.

### Command Timer
`POWERLEVEL9K_COMMAND_EXECUTION_TIME_*` controls the timer segment:
```zsh
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=2
```
Adjust the threshold or colors (`FOREGROUND`, `BACKGROUND`) to suit your workflow.

### Colors and Icons
Look for comments in `profiles/classic/p10k.zsh` describing segment-specific options. The fastest workflow:
1. Search for the segment name (e.g., `typeset -g POWERLEVEL9K_DIR_*`).
2. Un-comment and adjust color codes or icon expansions.
3. Restart your shell or run `source ~/.p10k.zsh`.

## `.zshrc` Lazy Loading
Each profile ships with its own `zshrc` (`profiles/classic/zshrc` or `profiles/pure/zshrc`). Both include a simple `zsh_defer` helper that delays sourcing heavy plugins until the next prompt. Customize it as follows:
- **Adding plugins:** Append another `if` block using `zsh_defer source /path/to/plugin.zsh`.
- **Removing plugins:** Delete the relevant block; `git` remains active via Oh My Zsh.
- **Always-on plugins:** Move the `source` call above the deferred section if you need a plugin loaded immediately.

### Pure Prompt Settings
The Pure profile exposes environment variables near the top of its `zshrc`. Common tweaks:
- `PURE_PROMPT_SYMBOL` – set a custom prompt glyph (default `❯`).
- `PURE_CMD_MAX_EXEC_TIME` – adjust the threshold in seconds before execution times are shown.
- `PURE_GIT_PULL=0` – disable automatic `git pull` reminders.
Refer to the [Pure README](https://github.com/sindresorhus/pure#options) for the full list.

### Fastfetch Welcome Screen
The classic profile prints a Fastfetch dashboard at startup when the binary is available. The installer generates `~/.config/fastfetch/config.jsonc` with a curated module list (OS, kernel, uptime, packages, shell, CPU/GPU, memory, disks, display, battery, media). Customize it by:
- Setting `FASTFETCH_DISABLE=1` to turn the banner off.
- Passing extra arguments with `FASTFETCH_FLAGS` (string or array). When unset, Fastfetch uses the config file under `~/.config/fastfetch/config.jsonc` created by the installer.
- Editing `profiles/classic/fastfetch_logo.txt` to change the ASCII art; re-run the installer to copy it to `~/.config/fastfetch/logo.txt` and refresh the config to point at that file.
Fastfetch binaries are downloaded from the official GitHub releases when missing; ensure `~/.local/bin` is on your `PATH` or adjust the install script to point elsewhere.

### Colorize Plugin
The Oh My Zsh `colorize` plugin provides colorized output for `cat`, `tail`, and other commands when `pygmentize` (Pygments) or `chroma` is available. Configure it via:
- `ZSH_COLORIZE_TOOL` (`pygmentize` or `chroma`, defaults to `pygmentize`).
- `ZSH_COLORIZE_STYLE` for the color theme (see `pygmentize -L styles`).
- `ZSH_COLORIZE_CHROMA_FORMATTER` when using `chroma`.
Set these variables before the deferred sourcing block.

### zsh-histdb
`zsh-histdb` stores command history in SQLite. This setup places the database under `${XDG_DATA_HOME:-~/.local/share}/histdb`. Customize by setting:
- `HISTDB_FILE` to an alternate database path.
- `HISTDB_SYNC_REMOTE=1` to enable cross-host sync (requires manual setup).
- `HISTDB_MAX_SIZE` to limit database size.
The plugin requires `sqlite3` and sourcing `sqlite-history.zsh`, handled automatically by the template.

### Completion Behavior
- Extra completion definitions from `zsh-completions` are mounted into `fpath` before `compinit` runs.
- `compinit` executes via `zsh_defer compinit -C -u`, using the cache file at `${XDG_CACHE_HOME:-~/.cache}/zsh/.zcompdump-*`.
- To reset completions, delete the compdump file and start a new shell.

## External Tools
`install_zsh.sh` tries to install `autojump`, `direnv`, `sqlite3`, and `python3-pygments` (for `pygmentize`) with `apt`. If you prefer a different package manager or want to skip installation entirely, remove or comment out the `ensure_command_available` calls in the script.

### Alternative Plugin Managers
You can integrate other managers (e.g., `antidote`, `zinit`) by replacing the relevant sections in `.zshrc`. Be sure to update this repository so linked machines stay in sync.

## Fonts
If you already manage fonts centrally, comment out or remove `install_meslo_fonts` in the script, or replace the URLs with alternative Nerd Fonts.

## Maintaining Forked Configs
When making local edits:
1. Update files under `profiles/<name>/`.
2. `git commit` the changes so machines using `--link` stay synchronized.
3. Re-run `install_zsh.sh --copy` or `--link` as needed to propagate updates (include `--profile` if you are targeting non-default profiles).

## Tips for Further Performance
- Disable rarely used Powerlevel10k segments to reduce prompt compute time.
- Keep `zsh-completions` in sync; older versions may include slow rules.
- Profile with `ZSH_PROFILE=1` after significant changes (see `docs/profiling.md`).

Happy customizing!
