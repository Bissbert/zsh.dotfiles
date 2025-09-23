# Zsh Config Installer

This repository provides a reproducible setup for a customized Zsh environment built on top of Oh My Zsh and the Powerlevel10k "Classic" prompt style. The installer script can either copy the tracked configuration files into place or symlink them directly from the repository, making it suitable for dotfiles management across machines.

## Highlights
- Oh My Zsh bootstrap/update with reproducible plugin set.
- Powerlevel10k classic prompt tuned for a single-line layout with curated segments (default profile).
- Optional Pure prompt profile sharing the same plugin stack and lazy-loading setup.
- Fastfetch welcome screen in the classic profile (disable with `FASTFETCH_DISABLE=1`).
- MesloLGS Nerd Font download to ensure glyph compatibility.
- Optional apt-based installation of external helpers (`autojump`, `direnv`), system dashboard (`fastfetch`), history storage (`sqlite3`), and syntax highlighting backend (`python3-pygments`).
- Lazy-loaded plugins including autosuggestions, history substring search, colorized file preview, and syntax highlighting.
- `zsh-histdb` integration for SQLite-backed command history, with XDG-friendly storage defaults.
- Config templates stored under version control; choose copy or symlink deployment (`--copy` or `--link`).
- Lazy-loaded plugins and deferred `compinit` for faster shell startup.
- Optional profiling hook to generate `zprof` reports for further tuning.

## Requirements
- Bash 4+, curl, git, and zsh available on the target system.
- Internet access to fetch Oh My Zsh, Powerlevel10k, plugins, and fonts.
- `apt`/`apt-get` (plus sudo rights) if you want the script to auto-install `autojump` and `direnv`.
- For the symlink mode, keep the repository accessible at the same path (e.g., via your dotfiles checkout).

## Repository Layout
```
README.md               – project overview (this file)
install_zsh.sh          – main installer (copy/symlink aware)
powerlevel10k.README.md – upstream theme documentation (reference only)
profiles/
  ├─ classic/           – Powerlevel10k profile templates (`p10k.zsh`, `zshrc`)
  └─ pure/              – Pure prompt profile template (`zshrc`, README)
docs/                   – supplementary guides (installation, customization, profiling)
```
Additional documentation lives under `docs/`.

## Quick Start
```bash
# clone or pull into your dotfiles directory
cd ~/dotfiles

# install the default Powerlevel10k profile
bash install_zsh.sh --link   # or --copy if you prefer duplication

# install the Pure profile instead
bash install_zsh.sh --profile pure --link
```

The script will:
1. Install or update Oh My Zsh under `~/.oh-my-zsh`.
2. Clone/update Powerlevel10k into `~/.oh-my-zsh/custom/themes/powerlevel10k`.
3. Clone/update the Pure prompt into `~/.oh-my-zsh/custom/themes/pure`.
4. Clone/update core plugins (`zsh-autosuggestions`, `zsh-completions`, `fast-syntax-highlighting`, `zsh-syntax-highlighting`, `zsh-histdb`).
5. Install MesloLGS Nerd Fonts into `~/.local/share/fonts` (Linux) or `~/Library/Fonts` (macOS).
6. Deploy `.zshrc` and, if present, `.p10k.zsh` via copy or symlink from the selected profile.
7. Attempt to install `autojump`, `direnv`, `sqlite3`, and `python3-pygments` (for `pygmentize`) using `apt`/`apt-get` when available.
8. Download a prebuilt Fastfetch binary from the official GitHub releases if it isn’t already on your PATH.
9. Back up previous dotfiles to `~/.zsh-backups/<timestamp>/` and log metadata in `install_manifest.txt`.
10. Switch your login shell to `zsh` using `chsh` (if not already set).

After the script finishes, open a new terminal session and set the profile font to **MesloLGS NF** in your terminal emulator.

## Copy vs Link Modes
- `--copy` *(default)*: copies template files and preserves existing files under `~/.zsh-backups/<timestamp>/`.
- `--link`: symlinks template files from the repository into place. Keep the repo accessible (e.g., via your dotfiles checkout) to ensure updates propagate automatically.
- `--help`: prints usage information.

## Profiling Shell Startup
Enable profiling by exporting `ZSH_PROFILE=1` before launching an interactive shell:
```bash
ZSH_PROFILE=1 zsh -i -c 'exit'
```
This writes a `zprof.<pid>.log` file into `~/.cache/zsh/`. Inspect the log to identify slow components (e.g., `_omz_source`, `compinit`, Powerlevel10k segments). See `docs/profiling.md` for interpretation tips.

## Customization
- Edit `profiles/classic/p10k.zsh` to change Powerlevel10k segments, thresholds, and colors.
- Adjust the profile-specific `zshrc` (`profiles/classic/zshrc` or `profiles/pure/zshrc`) to add/remove deferred plugins or tweak lazy-loading hooks.
- Update `profiles/classic/fastfetch_logo.txt` to change the ASCII welcome banner copied to `~/.config/fastfetch/logo.txt` (the generated `config.jsonc` points at that absolute path and seeds a standard module list).
- Set `ZSH_COLORIZE_TOOL`, `ZSH_COLORIZE_STYLE`, or `ZSH_COLORIZE_CHROMA_FORMATTER` to control the colorize plugin backend and theme.
- Override the history database location via `HISTDB_FILE` (defaults to `$XDG_DATA_HOME/histdb/zsh-history.db` in this setup). The plugin requires `sqlite3` and sourcing `sqlite-history.zsh`, which the template handles for you.
- If you do not need optional helpers (`autojump`, `direnv`, `sqlite3`, `pygmentize`), remove or comment out their install blocks in `install_zsh.sh`.
- Additional prompt segments can be enabled by adding them to the `POWERLEVEL9K_LEFT/RIGHT_PROMPT_ELEMENTS` arrays in `p10k-classic.zsh`.

For more detailed guidance, see:
- [`docs/installation.md`](docs/installation.md) – system preparation, script execution options, and rollback notes.
- [`docs/customization.md`](docs/customization.md) – prompt tweaks, plugin selection, and font tips.
- [`docs/profiling.md`](docs/profiling.md) – using `zprof` to investigate slow startups.
- [`docs/profiles.md`](docs/profiles.md) – overview of available profiles and how to add new ones.

## Troubleshooting
- **Prompt glyphs broken**: ensure your terminal font is set to MesloLGS Nerd Font after running the installer.
- **Slow completions**: confirm the compdump cache exists under `~/.cache/zsh/`. Profiling may reveal additional heavy plugins.
- **`autojump`/`direnv` warnings**: install the binaries manually if your system uses a package manager other than apt (the script records hints at the end).
- **`chsh` failed**: run `chsh -s $(which zsh)` manually with appropriate permissions.

## Contributing / Extending
- Commit template changes so that `--link` users automatically receive updates.
- Document any additional plugins or external dependencies in `docs/customization.md`.
- Use branches or tags to capture known-good configurations for specific machines.

Enjoy a reproducible and performant Zsh prompt!
