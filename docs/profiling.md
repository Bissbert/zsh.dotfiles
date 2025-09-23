# Profiling Zsh Startup

The configuration supports ad-hoc profiling via the environment variable `ZSH_PROFILE`. When set, Zsh loads the `zsh/zprof` module and dumps a report to `~/.cache/zsh/zprof.<pid>.log` on the first prompt and at shell exit.

## Running a Profile
```bash
ZSH_PROFILE=1 zsh -i -c 'exit'
```
Multiple shells can be profiled in parallel; each receives a unique PID-based log file.

## Reading the Report
The log is the standard `zprof` output sorted by self time. Typical heavy hitters:
- `_omz_source`: time spent loading Oh My Zsh core and plugins.
- `compinit`: completion system initialization (may trigger `compaudit`).
- `prompt_powerlevel9k_*`: Powerlevel10k setup.
- `zsh_defer`: wrapper function that reschedules deferred plugin loads.

Investigate entries with large self-time values. Common improvements:
- Disable unused segments in `p10k-classic.zsh` to reduce Powerlevel10k init time.
- Remove heavy plugins or move them to deferred loading in `zshrc`.
- Delete the compdump cache and re-run `compinit -C -u` if `compaudit` becomes slow on network mounts.

## Sharing Results
For consistent reproduction, attach the following to bug reports or commit messages:
- The relevant `zprof.*.log` file.
- The output of `git rev-parse HEAD` inside the repository (tracked automatically in `install_manifest.txt`).
- Any local edits applied to `zsh/` templates or the installer.

Profiling is optional but highly recommended after major configuration changes or when startup feels sluggish.
