# Profiles

The installer supports multiple configuration profiles stored under `profiles/`.

## classic
- Files: `profiles/classic/zshrc`, `profiles/classic/p10k.zsh`.
- Prompt: Powerlevel10k "Classic" preset with repo-specific overrides.
- Recommended font: MesloLGS NF (installed automatically).
- `.p10k.zsh` is deployed alongside `.zshrc`.

## pure
- Files: `profiles/pure/zshrc`, `profiles/pure/README.md`.
- Prompt: [Pure](https://github.com/sindresorhus/pure) asynchronous prompt.
- No `.p10k.zsh` is installed; Powerlevel10k remains available for optional use.
- `PURE_*` environment variables can be set near the top of the profile’s `zshrc`.

## Adding New Profiles
1. Create a folder under `profiles/<name>/` containing at least a `zshrc` template (and any other supporting files).
2. Reference `profiles/<name>/` in the README and docs as needed.
3. Run `install_zsh.sh --profile <name>` to deploy it (ensure the script knows how to handle any additional files your profile requires).

The default profile is `classic`. Use `--profile pure` (or another profile name) when running the installer to switch.
