[← back to the overview](../README.md)

# How this was measured

The numbers published in the README and this documentation come from commands
run during this pass. The measurement scripts are committed in `tools/`; their
JSON outputs retain the raw samples and host facts. No measurement changes the
repository’s tracked shell or profile files.

```mermaid
flowchart LR
    A["measurement script"] --> B["temporary HOME<br/>external checkouts"]
    B --> C["Zsh process<br/>PTY or command mode"]
    C --> D["timings and shell dumps"]
    D --> E["Markdown tables<br/>and JSON results"]

    style B fill:#1f6feb,stroke:#58a6ff,color:#fff
    style E fill:#238636,stroke:#3fb950,color:#fff
```

## Verification commands

These read-only checks passed:

```sh
bash -n install_zsh.sh
zsh -n profiles/classic/zshrc
zsh -n profiles/pure/zshrc
bash install_zsh.sh --help
```

The command output showed the installer’s supported copy, link, profile, and
help options. The full installer was attempted with a temporary `HOME`, but it
did not complete because of the inherited `ZSH` bug documented in
[`BUGS-FOUND.md`](BUGS-FOUND.md). No successful installation result is claimed.

## Startup benchmark

The command was:

```sh
python3 tools/bench_startup.py --reps 9
```

The script discards its warm-up round and records nine samples per variant. It
uses a temporary `HOME` containing shallow checkouts of the external trees
named by the installer. It writes the selected profile into that sandbox and
does not source the user’s real dotfiles.

The two timings are deliberately different:

- `first prompt` starts Zsh on a real PTY and stops after the first `precmd`
  marker. Deferred plugin hooks have run by that marker.
- `zsh -i -c exit` measures the command documented by the repository. It exits
  without reaching an interactive prompt, so it does not include the same
  deferred work.

The report prints the minimum sample as its headline. The measured minimums,
rounded to milliseconds by the reporting script, were:

| Configuration | First prompt | `zsh -i -c exit` |
|---|---:|---:|
| Bare Zsh, no `.zshrc` | 17 ms | 19 ms |
| Classic profile | 215 ms | 124 ms |
| Pure profile | 544 ms | 124 ms |

The JSON also records the host as an Apple M1 Max, Darwin arm64, with Zsh 5.9.
The result file was generated at the source revision recorded in its `host`
object. These are wall-clock samples, not portability claims.

## Shell inventory

The commands were:

```sh
python3 tools/inventory.py --profile classic --out tools/results_inventory.json
python3 tools/inventory.py --profile pure --out tools/results_inventory_pure.json
```

After the first prompt, the script dumped shell definitions and compared the
full profile with a bare Zsh baseline. The complete-shell deltas were:

| Profile | Aliases | Functions | Widgets | Key-binding lines | Completions |
|---|---:|---:|---:|---:|---:|
| Classic | 233 | 2,128 | 108 | 33 | 1,975 |
| Pure | 233 | 1,798 | 102 | 33 | 1,975 |

These counts describe names and definition lines present in the full shell
delta. They do not assign every definition to a unique plugin. The raw JSON
also contains per-block ablation diffs for investigation.

## Source-derived facts

The repository facts used in the overview were checked with shell commands:

```sh
find profiles -mindepth 1 -maxdepth 1 -type d | wc -l
grep -c '^    \[.*\]=https://' install_zsh.sh
git ls-files | wc -l
```

Those commands returned two profile directories, six plugin clone destinations,
and eleven tracked files before this documentation pass. The profile and
plugin lists themselves are copied from the tracked source, not inferred from
timings.

## What was not measured

No real installer transcript was captured as an animation. The pass ships
Mermaid diagrams only because the full install could not complete safely in the
isolated test and the documentation contract forbids presenting staged or
hand-written terminal output as a recording. Plugin revisions are shallow
checkout facts captured by the scripts; timings can change with network state,
revision drift, and machine load.
