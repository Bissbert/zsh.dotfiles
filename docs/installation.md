# Installation Guide

This document explains how to run `install_zsh.sh` and what happens behind the scenes.

## Prerequisites
- **System packages:** `bash`, `curl`, `git`, `zsh`.
- **Permissions:** Ability to run `chsh` (optional) and install packages via `apt`/`apt-get` with `sudo` if you want the script to install `autojump` and `direnv` for you.
- **Network access:** Required to download Oh My Zsh, Powerlevel10k, plugins, and fonts.

## Initial Setup
1. Clone or symlink this repository into your dotfiles directory: `git clone <repo-url> ~/dotfiles/zsh`.
2. (Optional) Commit any local modifications so they travel to other machines.

## Running the Installer
```bash
cd ~/dotfiles/zsh
bash install_zsh.sh          # copies by default
bash install_zsh.sh --link    # symlinks templates from the repo
bash install_zsh.sh --copy    # explicit copy mode
bash install_zsh.sh --help    # usage information
```

### What the Script Does
1. Ensures required commands exist (`curl`, `git`, `zsh`).
2. Creates a timestamped backup directory under `~/.zsh-backups/<timestamp>/`.
3. Installs or updates Oh My Zsh to `~/.oh-my-zsh`.
4. Installs or updates Powerlevel10k to `~/.oh-my-zsh/custom/themes/powerlevel10k`.
5. Installs/updates the plugin repositories (`zsh-autosuggestions`, `zsh-completions`, `fast-syntax-highlighting`, `zsh-syntax-highlighting`, `zsh-histdb`).
6. Installs MesloLGS Nerd Fonts to the appropriate fonts folder and refreshes the font cache (Linux).
7. Copies or symlinks `.zshrc` and `.p10k.zsh` from the `zsh/` folder.
8. Attempts to install `autojump`, `direnv`, `sqlite3`, and `python3-pygments` (for `pygmentize`) with `apt`/`apt-get` if missing.
9. Switches your default shell to Zsh using `chsh -s $(which zsh)` if necessary.
10. Writes `install_manifest.txt` inside the backup folder with the timestamp, script path, repo commit hash, and deployment mode.

## Post-Installation Steps
- Restart your terminal or run `exec zsh`.
- Configure your terminal emulator to use **MesloLGS NF** (Regular) for best glyph coverage.
- Verify the prompt: it should be a single-line Powerlevel10k prompt with git, status, timer, battery, and time segments.

## Re-running Safely
Re-run the script at any time; it will back up current files before applying updates. When using `--link`, ensure the repo path remains unchanged so symlinks stay valid.

## Rollback
All replaced files are stored in `~/.zsh-backups/<timestamp>/`. To revert:
1. Move or remove the current `~/.zshrc` / `~/.p10k.zsh`.
2. Copy the desired backup versions back into place.
3. Re-run `exec zsh`.

## Updating Across Machines
- Commit changes to the repository (especially within `zsh/`).
- On a new machine, clone the repo and run `bash install_zsh.sh --link` to pick up identical configuration.

## Troubleshooting
- **Fonts still wrong:** Some terminal apps require closing/relaunching after adding new fonts. On Linux, run `fc-cache -f ~/.local/share/fonts` manually if needed.
- **`apt` unavailable:** The script falls back to warnings; install `autojump`, `direnv`, `sqlite3`, and `Pygments` (`pygmentize`) using your system’s package manager (brew, dnf, pacman, etc.).
- **`chsh` fails:** Run `sudo chsh -s $(which zsh) $USER` or adjust `/etc/passwd` with admin assistance.

Happy hacking!
