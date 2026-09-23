#!/usr/bin/env python3
"""Measure zsh startup cost for every profile in this repository.

Two numbers are taken for each configuration:

  ttfp   time from exec to the last precmd hook of the first prompt, on a real
         pty.  This is the honest "how long until I can type" number: it
         includes everything zsh_defer postponed to the first prompt.
  noni   wall time of `zsh -i -c exit`, the command README.md documents.  It
         never reaches a prompt, so deferred plugins are NOT part of it.

Per-module costs come from ablation: the same profile is measured again with
one block removed, and the difference is that block's cost.

    python3 tools/bench_startup.py                 # measure, print a table
    python3 tools/bench_startup.py --reps 15       # more samples
    python3 tools/bench_startup.py --refresh       # re-clone the sandbox

Nothing outside the sandbox directory is touched; your own dotfiles are not
read, not written and not sourced.  Standard library only.
"""

import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zsandbox as z                                          # noqa: E402

# (label, needles for whole-block removal, regexes for single-line removal)
CLASSIC_ABLATIONS = [
    ("oh-my-zsh core",          [], [r'^source "\$ZSH/oh-my-zsh\.sh"']),
    ("compinit",                ["compinit -C"], []),
    ("zsh-histdb",              ["sqlite-history.zsh"], []),
    ("fzf-tab",                 ["fzf-tab.plugin.zsh"], []),
    ("p10k.zsh (prompt config)", [], [r'\.p10k\.zsh']),
    ("all deferred plugins",    ["zsh_defer source"], []),
    ("zsh-autosuggestions",     ["zsh-autosuggestions.zsh"], []),
    ("syntax highlighting",     ["fast-syntax-highlighting.plugin.zsh"], []),
    ("colored-man-pages",       ["colored-man-pages"], []),
    ("colorize",                ["colorize.plugin.zsh"], []),
    ("history-substring-search", ["history-substring-search"], []),
    ("autojump + direnv",       ["autojump", "direnv"], []),
    ("fzf key-bindings",        ["key-bindings.zsh"], []),
    ("fastfetch banner",        ["fastfetch"], []),
]

PURE_ABLATIONS = [
    ("oh-my-zsh core",          [], [r'^source "\$ZSH/oh-my-zsh\.sh"']),
    ("compinit",                ["compinit -C"], []),
    ("zsh-histdb",              ["sqlite-history.zsh"], []),
    ("fzf-tab",                 ["fzf-tab.plugin.zsh"], []),
    ("pure prompt",             [], [r'^promptinit\s*$', r'^prompt pure\s*$']),
    ("all deferred plugins",    ["zsh_defer source"], []),
]

PLANS = {"classic": CLASSIC_ABLATIONS, "pure": PURE_ABLATIONS}


def build_variants():
    """label -> zshrc body.  'baseline' is an empty rc: bare zsh + the probe."""
    variants = [("baseline", "", "")]
    for profile, ablations in PLANS.items():
        full = z.read_profile(profile)
        variants.append((profile, "full", full))
        for label, needles, drops in ablations:
            body = z.strip(full, needles, drops)
            if body == full:
                sys.stderr.write("  !! %s/%s: nothing removed, check the rule\n"
                                 % (profile, label))
            variants.append((profile, label, body))
    return variants


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sandbox", default=z.default_sandbox())
    ap.add_argument("--reps", type=int, default=9)
    ap.add_argument("--refresh", action="store_true",
                    help="delete and re-clone the sandbox plugin checkouts")
    ap.add_argument("--seed", type=int, default=20250921)
    ap.add_argument("--out", default=os.path.join(z.REPO, "tools",
                                                  "results_startup.json"))
    args = ap.parse_args()

    sys.stderr.write("sandbox: %s\n" % args.sandbox)
    shas = z.ensure_sandbox(args.sandbox, refresh=args.refresh)
    env = z.sandbox_env(args.sandbox)

    variants = build_variants()
    samples = {(p, l): {"ttfp": [], "noni": []} for p, l, _ in variants}
    bodies = {(p, l): b for p, l, b in variants}

    # Round-robin in a shuffled order rather than reps-in-a-row per variant.
    # This machine's load average moves during a run; interleaving spreads that
    # drift evenly instead of charging it to whichever variant ran last.
    rng = random.Random(args.seed)
    order = [(p, l) for p, l, _ in variants]
    for rnd in range(args.reps + 1):
        rng.shuffle(order)
        for key in order:
            z.write_variant(args.sandbox, bodies[key])
            t, _ = z.time_to_first_prompt(args.sandbox, env)
            n = z.time_noninteractive(env)
            if rnd == 0:
                continue          # discard the warm-up round
            samples[key]["ttfp"].append(t)
            samples[key]["noni"].append(n)
        sys.stderr.write("round %d/%d done\n" % (rnd, args.reps))

    results = {}
    for (profile, label), s in samples.items():
        entry = {"ttfp": z.stats(s["ttfp"]), "noni": z.stats(s["noni"])}
        if profile == "baseline":
            results["baseline"] = entry
        elif label == "full":
            results.setdefault(profile, {})["full"] = entry
        else:
            results.setdefault(profile, {}).setdefault(
                "ablations", {})[label] = entry

    payload = {"host": z.host_facts(), "plugin_commits": shas,
               "reps": args.reps, "seed": args.seed, "results": results}
    z.dump(args.out, payload)
    report(payload)


def report(payload, stat="min"):
    """`min` is the headline number: the fastest run is the one least
    contaminated by whatever else the machine was doing."""
    r = payload["results"]
    base = r["baseline"]
    ms = lambda e, k: e[k][stat] * 1000                       # noqa: E731
    print("\n| configuration | time to first prompt | `zsh -i -c exit` |")
    print("|---|---:|---:|")
    print("| bare zsh, no zshrc | %.0f ms | %.0f ms |"
          % (ms(base, "ttfp"), ms(base, "noni")))
    for profile in ("classic", "pure"):
        f = r[profile]["full"]
        print("| %s profile | %.0f ms | %.0f ms |"
              % (profile, ms(f, "ttfp"), ms(f, "noni")))

    for profile in ("classic", "pure"):
        full = r[profile]["full"]["ttfp"][stat]
        print("\n### %s -- cost per block (ablation)\n" % profile)
        print("| removed block | first prompt without it | cost of the block |")
        print("|---|---:|---:|")
        rows = [(full - res["ttfp"][stat], label, res["ttfp"][stat])
                for label, res in r[profile]["ablations"].items()]
        for delta, label, val in sorted(rows, reverse=True):
            print("| %s | %.0f ms | %+.0f ms |" % (label, val * 1000,
                                                   delta * 1000))


if __name__ == "__main__":
    main()
