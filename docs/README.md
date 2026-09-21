[← back to the overview](../README.md)

# Documentation

Each page below explains a subsystem of the installer or a deployed profile.
The diagrams show control flow and source order; the measurement page ties
published numbers to the scripts in `tools/`.

| Area | Write-up | In one line |
|---|---|---|
| Installation | [`installation.md`](installation.md) | Deployment, update, backup, and rollback flow. |
| Profiles | [`profiles.md`](profiles.md) | Classic and Pure load order, prompt choice, and override point. |
| Customization | [`customization.md`](customization.md) | What the completion, history, prompt, and plugin modules provide. |
| Startup profiling | [`profiling.md`](profiling.md) | `zprof`, first-prompt timing, and ablation measurements. |
| Measurement | [`measurement.md`](measurement.md) | Commands, sandbox, provenance, and limitations of every published number. |
| Bugs found | [`BUGS-FOUND.md`](BUGS-FOUND.md) | Reproduction notes for behavior discovered during this pass. |

The measurement scripts are in [`../tools/`](../tools). They use only Python’s
standard library and write their JSON results beside themselves.
