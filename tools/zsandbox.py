"""Shared helpers for the measurement scripts in tools/.

Everything the benchmarks do happens inside a throwaway HOME directory so that
the machine running them keeps its own dotfiles.  The sandbox is populated with
exactly the repositories install_zsh.sh would clone, from the same URLs.

Python 3.8+, standard library only.
"""

import json
import os
import pty
import re
import select
import shutil
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The same set install_zsh.sh clones, keyed by destination inside the sandbox.
REPOS = {
    ".oh-my-zsh": "https://github.com/ohmyzsh/ohmyzsh.git",
    ".oh-my-zsh/custom/themes/powerlevel10k":
        "https://github.com/romkatv/powerlevel10k.git",
    ".oh-my-zsh/custom/themes/pure":
        "https://github.com/sindresorhus/pure.git",
    ".oh-my-zsh/custom/plugins/zsh-autosuggestions":
        "https://github.com/zsh-users/zsh-autosuggestions.git",
    ".oh-my-zsh/custom/plugins/zsh-completions":
        "https://github.com/zsh-users/zsh-completions.git",
    ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting":
        "https://github.com/zsh-users/zsh-syntax-highlighting.git",
    ".oh-my-zsh/custom/plugins/fast-syntax-highlighting":
        "https://github.com/zdharma-continuum/fast-syntax-highlighting.git",
    ".oh-my-zsh/custom/plugins/zsh-histdb":
        "https://github.com/larkery/zsh-histdb.git",
    ".oh-my-zsh/custom/plugins/fzf-tab":
        "https://github.com/Aloxaf/fzf-tab.git",
}

MARKER = "__ZBENCH_READY__"

# Appended to every variant.  It runs as the last precmd hook of the first
# prompt, which means every zsh_defer'd plugin has already been loaded by the
# time the marker appears.
PROBE = """
autoload -Uz add-zsh-hook
__zbench_ready() {{
  print -r -- "{marker}"
  add-zsh-hook -d precmd __zbench_ready
}}
add-zsh-hook precmd __zbench_ready
""".format(marker=MARKER)


# ---------------------------------------------------------------- sandbox ---

def default_sandbox():
    return os.environ.get("ZBENCH_SANDBOX") or os.path.join(
        os.environ.get("TMPDIR", "/tmp"), "zsh-dotfiles-bench")


def ensure_sandbox(sandbox, refresh=False):
    """Clone (or reuse) the plugin set into `sandbox`.  Returns pinned SHAs."""
    os.makedirs(sandbox, exist_ok=True)
    shas = {}
    for rel, url in REPOS.items():
        dest = os.path.join(sandbox, rel)
        if refresh and os.path.isdir(dest):
            shutil.rmtree(dest)
        if not os.path.isdir(os.path.join(dest, ".git")):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            sys.stderr.write("  cloning %s\n" % rel)
            subprocess.run(["git", "clone", "--depth=1", "--quiet", url, dest],
                           check=True)
        shas[rel] = subprocess.run(
            ["git", "-C", dest, "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True).stdout.strip()
    # The installer deploys .p10k.zsh next to .zshrc; the classic profile
    # sources it unconditionally, so it belongs in the sandbox.
    shutil.copy(os.path.join(REPO, "profiles", "classic", "p10k.zsh"),
                os.path.join(sandbox, ".p10k.zsh"))
    for sub in (".cache/zsh", ".local/share/histdb", ".local/bin"):
        os.makedirs(os.path.join(sandbox, sub), exist_ok=True)
    return shas


def sandbox_env(sandbox, extra=None):
    env = dict(os.environ)
    env.update({
        "HOME": sandbox,
        "ZDOTDIR": sandbox,
        "TERM": "xterm-256color",
        "LANG": env.get("LANG", "en_US.UTF-8"),
        "COLUMNS": "120",
        "LINES": "40",
    })
    for stray in ("ZSH_PROFILE", "ZSH", "ZSH_CUSTOM", "ZSH_THEME",
                  "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME"):
        env.pop(stray, None)
    if extra:
        env.update(extra)
    return env


# ---------------------------------------------------------------- variants --

def read_profile(profile):
    with open(os.path.join(REPO, "profiles", profile, "zshrc")) as fh:
        return fh.read()


def top_level_blocks(text):
    """Split a zshrc into (kind, text) chunks.

    A chunk is either a top-level `if ... fi` block (both keywords in column 0,
    which is how both profiles are written) or a run of other lines.
    """
    lines = text.splitlines(keepends=True)
    out, buf, i = [], [], 0
    while i < len(lines):
        if re.match(r"^(if|while|for)\b", lines[i]):
            start = i
            end = None
            for j in range(i + 1, len(lines)):
                if re.match(r"^(fi|done)\s*$", lines[j]):
                    end = j
                    break
            if end is not None:
                if buf:
                    out.append(("plain", "".join(buf)))
                    buf = []
                out.append(("block", "".join(lines[start:end + 1])))
                i = end + 1
                continue
        buf.append(lines[i])
        i += 1
    if buf:
        out.append(("plain", "".join(buf)))
    return out


def strip(text, needles, drop_lines=()):
    """Remove every top-level block mentioning any of `needles`.

    `drop_lines` removes individual lines matching a regex, for statements that
    are not wrapped in a block (the bare `source $ZSH/oh-my-zsh.sh`).
    """
    kept = []
    for kind, chunk in top_level_blocks(text):
        if kind == "block" and any(n in chunk for n in needles):
            continue
        kept.append(chunk)
    text = "".join(kept)
    for pattern in drop_lines:
        text = "\n".join(l for l in text.split("\n")
                         if not re.search(pattern, l))
    return text


def write_variant(sandbox, body):
    with open(os.path.join(sandbox, ".zshrc"), "w") as fh:
        fh.write(body)
        fh.write(PROBE)


# ------------------------------------------------------------------- runs ---

def time_to_first_prompt(sandbox, env, timeout=60.0):
    """Seconds from exec to the last precmd hook of the first prompt.

    zsh runs on a real pty, so `[[ -t 1 ]]` guards behave the way they do in a
    terminal and the deferred plugins actually get loaded.
    """
    pid, fd = pty.fork()
    if pid == 0:                                  # child
        os.execve("/bin/zsh", ["zsh", "-i"], env)
    start = time.perf_counter()
    buf, elapsed = b"", None
    deadline = start + timeout
    try:
        while time.perf_counter() < deadline:
            r, _, _ = select.select([fd], [], [], 0.25)
            if not r:
                continue
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            if MARKER.encode() in buf:
                elapsed = time.perf_counter() - start
                break
    finally:
        try:
            os.write(fd, b"exit\n")
        except OSError:
            pass
        try:
            os.close(fd)
        except OSError:
            pass
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
    if elapsed is None:
        raise RuntimeError("marker never appeared; last output:\n"
                           + buf.decode("utf-8", "replace")[-2000:])
    return elapsed, buf.decode("utf-8", "replace")


def run_and_send(sandbox, env, command, until, timeout=120.0):
    """Reach the first prompt, then type `command` and wait for `until`.

    Used by inventory.py: by the time the first prompt is up, every deferred
    plugin has loaded, so what the shell reports about itself is the complete
    picture rather than the half-loaded state `zsh -i -c` would show.
    """
    pid, fd = pty.fork()
    if pid == 0:
        os.execve("/bin/zsh", ["zsh", "-i"], env)
    buf, seen_prompt, done = b"", False, False
    deadline = time.perf_counter() + timeout
    try:
        while time.perf_counter() < deadline:
            r, _, _ = select.select([fd], [], [], 0.25)
            if not r:
                continue
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            if not seen_prompt and MARKER.encode() in buf:
                seen_prompt = True
                time.sleep(0.2)          # let the prompt finish drawing
                os.write(fd, command.encode())
            elif seen_prompt and until.encode() in buf.split(
                    MARKER.encode(), 1)[1]:
                done = True
                break
    finally:
        try:
            os.write(fd, b"\nexit\n")
        except OSError:
            pass
        try:
            os.close(fd)
        except OSError:
            pass
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
    if not done:
        raise RuntimeError("never saw %r; last output:\n%s"
                           % (until, buf.decode("utf-8", "replace")[-2000:]))
    return buf.decode("utf-8", "replace")


def time_noninteractive(env, timeout=60.0):
    """Seconds for `zsh -i -c exit` -- the command the README documents."""
    start = time.perf_counter()
    subprocess.run(["zsh", "-i", "-c", "exit"], env=env, timeout=timeout,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return time.perf_counter() - start


def stats(samples):
    s = sorted(samples)
    n = len(s)
    med = s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2
    return {"n": n, "min": s[0], "median": med, "max": s[-1]}


def host_facts():
    def run(*cmd):
        try:
            return subprocess.run(cmd, capture_output=True, text=True,
                                  check=True).stdout.strip()
        except Exception:
            return None
    facts = {
        "platform": sys.platform,
        "uname": run("uname", "-srm"),
        "zsh": run("zsh", "--version"),
        "repo_commit": run("git", "-C", REPO, "rev-parse", "HEAD"),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    if sys.platform == "darwin":
        facts["cpu"] = run("sysctl", "-n", "machdep.cpu.brand_string")
        facts["os"] = run("sw_vers", "-productVersion")
    facts["optional_tools"] = {
        tool: bool(shutil.which(tool))
        for tool in ("fastfetch", "autojump", "direnv", "sqlite3",
                     "pygmentize", "eza", "exa", "fzf")
    }
    return facts


def dump(path, payload):
    with open(path, "w") as fh:
        json.dump(payload, fh, indent=2, sort_keys=True)
        fh.write("\n")
    sys.stderr.write("wrote %s\n" % path)
