#!/usr/bin/env python3
"""Count what each block of a profile actually adds to an interactive shell.

Same sandbox and same ablation trick as bench_startup.py, but instead of
timing the shell it interrogates it: once the first prompt is reached (so every
zsh_defer'd plugin has loaded), the shell dumps its aliases, functions, key
bindings and completion functions.  Removing a block and diffing the dumps
attributes each name to the block that defined it.

    python3 tools/inventory.py
    python3 tools/inventory.py --show "zsh-autosuggestions"   # list the names

Standard library only; nothing outside the sandbox is touched.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zsandbox as z                                          # noqa: E402
from bench_startup import PLANS                               # noqa: E402

DUMP_MARKER = "__ZBENCH_DUMPED__"
DUMP_DIR = ".zbench"

DUMP_SCRIPT = """
zmodload zsh/zutil 2>/dev/null
print -rl -- ${{(ok)aliases}} ${{(ok)galiases}} ${{(ok)saliases}} > $HOME/{d}/aliases
print -rl -- ${{(ok)functions}} > $HOME/{d}/functions
print -rl -- ${{(ok)widgets}} > $HOME/{d}/widgets
bindkey -L > $HOME/{d}/bindkey
print -rl -- ${{(ok)_comps}} > $HOME/{d}/comps
print -rl -- $fpath > $HOME/{d}/fpath
print -r -- {m}
""".format(d=DUMP_DIR, m=DUMP_MARKER)

FIELDS = ("aliases", "functions", "widgets", "bindkey", "comps", "fpath")


def collect(sandbox, env, body):
    """Load `body` as the zshrc and return {field: set(lines)}."""
    z.write_variant(sandbox, body)
    out = os.path.join(sandbox, DUMP_DIR)
    os.makedirs(out, exist_ok=True)
    for f in FIELDS:
        try:
            os.unlink(os.path.join(out, f))
        except OSError:
            pass
    with open(os.path.join(out, "dump.zsh"), "w") as fh:
        fh.write(DUMP_SCRIPT)
    z.run_and_send(sandbox, env, "source $HOME/%s/dump.zsh\n" % DUMP_DIR,
                   DUMP_MARKER)
    data = {}
    for f in FIELDS:
        path = os.path.join(out, f)
        with open(path) as fh:
            data[f] = set(l.rstrip("\n") for l in fh if l.strip())
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sandbox", default=z.default_sandbox())
    ap.add_argument("--profile", default="classic", choices=sorted(PLANS))
    ap.add_argument("--show", help="print the names contributed by this block")
    ap.add_argument("--out", default=os.path.join(z.REPO, "tools",
                                                  "results_inventory.json"))
    args = ap.parse_args()

    shas = z.ensure_sandbox(args.sandbox)
    env = z.sandbox_env(args.sandbox)

    full_body = z.read_profile(args.profile)
    base = collect(args.sandbox, env, "")
    full = collect(args.sandbox, env, full_body)

    rows = {"(everything, vs. bare zsh)":
            {f: sorted(full[f] - base[f]) for f in FIELDS}}
    for label, needles, drops in PLANS[args.profile]:
        body = z.strip(full_body, needles, drops)
        if body == full_body:
            continue
        without = collect(args.sandbox, env, body)
        rows[label] = {f: sorted(full[f] - without[f]) for f in FIELDS}

    payload = {"host": z.host_facts(), "plugin_commits": shas,
               "profile": args.profile,
               "counts": {k: {f: len(v) for f, v in d.items()}
                          for k, d in rows.items()},
               "names": {k: {f: v for f, v in d.items()} for k, d in rows.items()}}
    z.dump(args.out, payload)

    if args.show:
        for f in FIELDS:
            print("## %s" % f)
            for name in rows[args.show][f]:
                print("   ", name)
        return

    print("\n### %s -- what each block contributes\n" % args.profile)
    print("| block | aliases | functions | widgets | key bindings | completions |")
    print("|---|---:|---:|---:|---:|---:|")
    for label, d in rows.items():
        print("| %s | %d | %d | %d | %d | %d |" % (
            label, len(d["aliases"]), len(d["functions"]), len(d["widgets"]),
            len(d["bindkey"]), len(d["comps"])))


if __name__ == "__main__":
    main()
