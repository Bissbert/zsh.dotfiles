# Pure Profile

This profile swaps Powerlevel10k for the [Pure](https://github.com/sindresorhus/pure) prompt while keeping the same plugin stack, lazy-loading helpers, and histdb integration.

## Key Differences
- `prompt pure` replaces Powerlevel10k; no `.p10k.zsh` file is installed.
- Pure’s functions (`prompt_pure_setup`, `async.zsh`) are pulled from the Oh My Zsh custom theme directory (`$ZSH_CUSTOM/themes/pure`).
- Optional Pure environment variables can be set near the top of `zshrc` (e.g., `PURE_PROMPT_SYMBOL`, `PURE_CMD_MAX_EXEC_TIME`).

## Usage
1. Ensure the installer has cloned the Pure theme (the main script handles this automatically).
2. Run `install_zsh.sh --profile pure` (optionally with `--link`) to deploy the template.
3. Restart your terminal; the prompt should match Pure’s single-line aesthetic with async git status.

## Notes
- Lazy-loaded plugins and history settings mirror the classic profile, so completion speed improvements remain.
- The colorize plugin still requires `pygmentize` (Pygments) or `chroma`.
- The history database lives under `${XDG_DATA_HOME:-~/.local/share}/histdb/zsh-history.db`.

Customize as needed, and commit changes to keep linked machines in sync.
