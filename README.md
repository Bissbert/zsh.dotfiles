# Zsh Config Installer

This repository installs a reproducible Zsh environment built around Oh My Zsh,
with Powerlevel10k Classic or Pure as the prompt, a shared completion and
history stack, and copy or symlink deployment. The installer updates external
checkouts, backs up files it replaces, and records the selected profile and
deployment mode in an install manifest.

```mermaid
flowchart LR
    R["tracked profiles<br/>classic or pure"] --> I["install_zsh.sh"]
    I --> O["Oh My Zsh<br/>themes and plugins"]
    I --> H["user home<br/>.zshrc and prompt files"]
    H --> S["interactive Zsh<br/>prompt and tools"]

    style R fill:#1f6feb,stroke:#58a6ff,color:#fff
    style S fill:#238636,stroke:#3fb950,color:#fff
```

## Quick start

```sh
git clone https://github.com/Bissbert/zsh.dotfiles.git ~/dotfiles/zsh.dotfiles
cd ~/dotfiles/zsh.dotfiles

# Inspect the supported deployment options.
bash install_zsh.sh --help

# Deploy the classic profile as symlinks.
bash install_zsh.sh --link
```

The help command, shell syntax checks, and the measurement harness were run for
this pass. The full installer command was also attempted in an isolated home,
but did not complete because an inherited `ZSH` environment variable made the
Oh My Zsh bootstrap select the real home checkout. That defect has since been
fixed on the default branch: the bootstrap is now passed the installer's own
target. The end-to-end run was not repeated afterwards, so the command above is
still source-defined but untested to completion here. See
[`docs/BUGS-FOUND.md`](docs/BUGS-FOUND.md) and the limitation below.

Use `--copy` instead of `--link` for independent deployed files, or select the
Pure prompt with `--profile pure`:

```sh
bash install_zsh.sh --copy
bash install_zsh.sh --profile pure --link
```

## How a profile loads

The selected profile is deployed as `~/.zshrc` (or under `ZDOTDIR`). The profile
sets paths and history locations, sources the core, initializes completion,
loads `fzf-tab`, registers deferred plugins, and then reaches the prompt. The
classic profile also sources `~/.p10k.zsh`; Pure loads its prompt from the
custom theme directory instead.

```mermaid
flowchart TD
    A["Zsh starts<br/>reads deployed .zshrc"] --> B["Set ZSH, cache,<br/>PATH and HISTDB_FILE"]
    B --> C["Source zsh-histdb<br/>when available"]
    C --> D["Source Oh My Zsh<br/>plugins = git"]
    D --> E["Initialize compinit<br/>with cached dump"]
    E --> F["Source fzf-tab<br/>set completion styles"]
    F --> G["Register deferred plugins<br/>and optional fzf bindings"]
    G --> H{"profile"}
    H -->|classic| I["Source ~/.p10k.zsh"]
    H -->|pure| J["promptinit<br/>prompt pure"]
    I --> K["First prompt<br/>deferred hooks run"]
    J --> K
    K --> L["User overrides belong at the<br/>end of the selected profile template"]

    style D fill:#1f6feb,stroke:#58a6ff,color:#fff
    style K fill:#238636,stroke:#3fb950,color:#fff
    style L fill:#8250df,stroke:#bc8cff,color:#fff
```

There is no separate override file in this repository. Put persistent shell
overrides at the end of `profiles/classic/zshrc` or `profiles/pure/zshrc`; put
Powerlevel10k segment changes in `profiles/classic/p10k.zsh`. With `--link`,
the deployed file points back to the repository, so editing the target edits
the checkout too.

## Installer and update flow

```mermaid
flowchart TD
    A["install_zsh.sh<br/>parse mode and profile"] --> B["Check curl, git, zsh,<br/>tar and find"]
    B --> C["Create ~/.zsh-backups/<br/>timestamp/"]
    C --> D{"checkout exists?"}
    D -->|yes| E["git pull --ff-only"]
    D -->|no| F["git clone --depth=1"]
    E --> G["Install or update<br/>themes and plugins"]
    F --> G
    G --> H["Optional tools and fonts<br/>with warnings on failure"]
    H --> I["Back up existing targets<br/>then copy or symlink"]
    I --> J["Write install_manifest.txt<br/>and try chsh"]
    J --> K["New shell uses the profile"]
    I -. back out .-> L["Remove current targets<br/>restore files from backup"]

    style G fill:#1f6feb,stroke:#58a6ff,color:#fff
    style J fill:#238636,stroke:#3fb950,color:#fff
    style L fill:#9e6a03,stroke:#d29922,color:#fff
```

Existing `.zshrc` and `.p10k.zsh` files are copied into the timestamped backup
directory before deployment. The classic profile also backs up an existing
Fastfetch logo. Updating an existing checkout is a fast-forward-only pull.
Pure does not provide a Powerlevel10k template; if a `.p10k.zsh` already exists,
the installer leaves it in place.

## Profiles and capabilities

| Capability | Classic | Pure |
|---|---|---|
| Prompt | Powerlevel10k Classic | Pure async prompt |
| Prompt config | `~/.p10k.zsh` from the profile | no new `.p10k.zsh` |
| Fastfetch banner | terminal-only, when available | not configured |
| Oh My Zsh core and `git` plugin | yes | yes |
| `zsh-completions`, `compinit`, `fzf-tab` | yes | yes |
| SQLite-backed `zsh-histdb` | yes, when its script is present | yes, when its script is present |
| Deferred suggestions and syntax highlighting | yes | yes |
| Optional `autojump`, `direnv`, and fzf bindings | detected at startup | detected at startup |

The profile-specific details and source order are in
[`docs/profiles.md`](docs/profiles.md). The module-to-capability table is in
[`docs/customization.md`](docs/customization.md).

## Measured startup cost

The following values are the fastest result from nine post-warm-up samples on
one Apple M1 Max running Darwin arm64 with Zsh 5.9. `first prompt` uses a real
PTY and includes deferred hooks; `zsh -i -c exit` does not reach a prompt.

| Configuration | First prompt | `zsh -i -c exit` |
|---|---:|---:|
| Bare Zsh, no `.zshrc` | 17 ms | 19 ms |
| Classic profile | 215 ms | 124 ms |
| Pure profile | 544 ms | 124 ms |

The complete interactive-shell inventory for Classic differed from bare Zsh by
233 aliases, 2,128 functions, 108 widgets, 33 key-binding lines, and 1,975
completion definitions in the same sandbox. Those are shell-surface diffs, not
claims that each name belongs uniquely to one plugin.

See [`docs/measurement.md`](docs/measurement.md) for commands, sampling rules,
sandbox details, and the raw JSON produced by the tools.

## Repository layout

```text
README.md                 illustrated overview and measured headline
install_zsh.sh            copy/link installer and updater
profiles/classic/         Powerlevel10k profile and Fastfetch assets
profiles/pure/            Pure prompt profile and notes
docs/                     subsystem write-ups and measurement method
tools/                    standard-library measurement scripts and results
```

## Known limitations

- The full installer was not verified to completion in this environment. The
  inherited-`ZSH` defect that blocked the attempt has been fixed on the default
  branch, but the end-to-end run was not repeated; the observed case is
  documented in [`docs/BUGS-FOUND.md`](docs/BUGS-FOUND.md).
- Installation and updates need network access. Optional package installation
  is apt-based, and changing the login shell depends on `chsh` permissions.
- `--link` requires the repository to remain at the same path. `--copy` avoids
  that coupling but must be rerun after profile changes.
- The profiles defer plugin sources until the first prompt. The noninteractive
  `zsh -i -c exit` number therefore understates the interactive first-prompt
  cost.
- The startup results use shallow external checkouts in a temporary sandbox;
  plugin revisions and machine load can change the timings.
- No terminal animation is shipped. The diagrams are Mermaid source diagrams;
  no real installer transcript was captured for an animation.

More detail is indexed in [`docs/README.md`](docs/README.md).
