#!/usr/bin/env python3
"""Static checks for every mode in this pack.

A mode is a top-level folder containing main.lua. For each one this checks:

* main.lua compiles as Lua 5.1 (LuaJIT, the engine's Lua, is 5.1-compatible).
* Every e.param(...) / eyesy.param(...) call with literal arguments has a knob
  in 0..5, no knob 1..5 is bound by two parameters, and parameter names are
  unique within the mode. Calls with non-literal arguments are skipped.
* Every e.shader(...) / eyesy.shader(...) call with a literal path names a file
  that exists in the mode folder.

Usage:
  tools/check_modes.py [MODE ...] [--lua-compiler luac5.1]

Exit 0 when every mode passes, 1 on any problem, 2 when no Lua compiler is found.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILERS = (("luac5.1", ["-p"]), ("luajit", ["-bl"]))
KNOB_MAX = 5
CALL_RE = r"(?<![\w.])(?:e|eyesy)\.%s\s*\("
STRING_RE = re.compile(r'^(?:"([^"\\]*)"|\'([^\'\\]*)\')$')
INT_RE = re.compile(r"^-?\d+$")


def _long_end(source: str, start: int) -> int:
    """Index just past the long bracket ([[...]], [==[...]==]) opening at start."""
    level = len(re.match(r"\[(=*)\[", source[start:]).group(1))
    close = source.find("]" + "=" * level + "]", start)
    return len(source) if close < 0 else close + level + 2


def strip_comments(source: str) -> str:
    """Blank out Lua comments. Same length as the input, line breaks kept."""
    out = []
    i, n = 0, len(source)
    while i < n:
        c = source[i]
        if c in "\"'":
            j = i + 1
            while j < n and source[j] != c and source[j] != "\n":
                j += 2 if source[j] == "\\" else 1
            out.append(source[i : j + 1])
            i = j + 1
        elif re.match(r"\[=*\[", source[i:]):
            end = _long_end(source, i)
            out.append(source[i:end])
            i = end
        elif source.startswith("--", i):
            m = re.match(r"--\[(=*)\[", source[i:])
            if m:
                end = source.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = source.find("\n", i)
                end = n if end < 0 else end
            out.append("".join(ch if ch == "\n" else " " for ch in source[i:end]))
            i = end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def mask_strings(source: str) -> str:
    """Same length as source, with string-literal interiors replaced by '_'.
    Lets call scanning ignore text inside strings; positions still line up."""
    out = list(source)
    i, n = 0, len(source)
    while i < n:
        if re.match(r"\[=*\[", source[i:]):
            end = _long_end(source, i)
            opener = len(re.match(r"\[=*\[", source[i:]).group(0))
            for k in range(i + opener, end - opener):
                if source[k] != "\n":
                    out[k] = "_"
            i = end
        elif source[i] in "\"'":
            quote = source[i]
            j = i + 1
            while j < n and source[j] != quote and source[j] != "\n":
                if source[j] == "\\":
                    out[j] = "_"
                    j += 1
                    if j < n and source[j] != "\n":
                        out[j] = "_"
                    j += 1
                    continue
                out[j] = "_"
                j += 1
            i = j + 1
        else:
            i += 1
    return "".join(out)


def split_args(source: str, open_paren: int) -> list[str]:
    """Top-level argument texts of the call whose '(' is at open_paren.

    `source` is the masked text (strings blanked) used for scanning, so the
    returned spans are cut from the original text by the caller."""
    spans, depth, start, i = [], 0, open_paren + 1, open_paren
    while i < len(source):
        c = source[i]
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
            if depth == 0:
                spans.append((start, i))
                return spans
        elif c == "," and depth == 1:
            spans.append((start, i))
            start = i + 1
        i += 1
    return []  # unterminated call; the compiler reports the syntax error


def calls(source: str, masked: str, name: str):
    """Yield (line, args) for each e.<name>(...) or eyesy.<name>(...) call.
    args are the original argument texts, stripped; empty ones dropped."""
    for m in re.finditer(CALL_RE % name, masked):
        line = source.count("\n", 0, m.start()) + 1
        spans = split_args(masked, m.end() - 1)
        args = [source[a:b].strip() for a, b in spans]
        yield line, [a for a in args if a]


def literal_string(arg: str) -> str | None:
    m = STRING_RE.match(arg)
    if not m:
        return None
    return m.group(1) if m.group(1) is not None else m.group(2)


def find_compiler(override: str | None) -> tuple[str, list[str]] | None:
    if override:
        return (override, ["-bl"] if "luajit" in override else ["-p"]) if shutil.which(override) else None
    for name, flags in COMPILERS:
        if shutil.which(name):
            return name, flags
    return None


def syntax_problem(path: Path, compiler: tuple[str, list[str]]) -> str | None:
    name, flags = compiler
    proc = subprocess.run(
        [name, *flags, str(path)], capture_output=True, text=True, check=False
    )
    if proc.returncode == 0:
        return None
    detail = (proc.stderr or proc.stdout).strip().splitlines()
    return "syntax: " + (detail[0] if detail else "compiler rejected main.lua")


def check_mode(mode: Path, compiler: tuple[str, list[str]]) -> tuple[list[str], int, int]:
    """Return (problems, param count, shader count) for one mode folder."""
    problems: list[str] = []
    main = mode / "main.lua"
    syntax = syntax_problem(main, compiler)
    if syntax:
        problems.append(syntax)

    source = strip_comments(main.read_text(encoding="utf-8", errors="replace"))
    masked = mask_strings(source)

    names: dict[str, int] = {}
    knobs: dict[int, str] = {}
    params = 0
    for line, args in calls(source, masked, "param"):
        params += 1
        name = literal_string(args[0]) if len(args) > 0 else None
        if len(args) < 5:
            problems.append(f"line {line}: param call has no knob argument")
            continue
        knob_arg = args[4]
        if name is None or not INT_RE.match(knob_arg):
            continue  # non-literal arguments: not checkable statically
        knob = int(knob_arg)
        if not 0 <= knob <= KNOB_MAX:
            problems.append(f"line {line}: param '{name}' uses knob {knob}, must be 0..{KNOB_MAX}")
        elif knob > 0 and knob in knobs:
            problems.append(
                f"line {line}: knob {knob} bound to both '{knobs[knob]}' and '{name}'"
            )
        else:
            knobs.setdefault(knob, name)
        if name in names:
            problems.append(f"line {line}: param '{name}' already declared at line {names[name]}")
        else:
            names[name] = line

    shaders = 0
    for line, args in calls(source, masked, "shader"):
        shaders += 1
        path = literal_string(args[0]) if args else None
        if path is None:
            continue
        if not (mode / path).is_file():
            problems.append(f"line {line}: shader '{path}' not found in mode folder")

    return problems, params, shaders


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("modes", nargs="*", help="mode folder names (default: all)")
    parser.add_argument("--lua-compiler", help="Lua compiler to use (default: luac5.1, then luajit)")
    args = parser.parse_args()

    compiler = find_compiler(args.lua_compiler)
    if compiler is None:
        print("error: no Lua 5.1 compiler found (install lua5.1 for luac5.1, or luajit)", file=sys.stderr)
        return 2

    if args.modes:
        modes = [ROOT / m for m in args.modes]
    else:
        modes = sorted(
            p for p in ROOT.iterdir()
            if p.is_dir() and not p.name.startswith(".") and (p / "main.lua").is_file()
        )
    missing = [m.name for m in modes if not (m / "main.lua").is_file()]
    if missing:
        print(f"error: no main.lua in: {', '.join(missing)}", file=sys.stderr)
        return 2

    failed = 0
    params = shaders = 0
    for mode in modes:
        problems, p, s = check_mode(mode, compiler)
        params += p
        shaders += s
        if problems:
            failed += 1
            for problem in problems:
                print(f"{mode.name}: {problem}")

    if failed:
        print(f"FAIL — {failed} of {len(modes)} mode(s) have problems")
        return 1
    print(
        f"PASS — {len(modes)} mode(s), {params} param call(s), {shaders} shader call(s): "
        f"syntax, knobs, names and shader paths clean ({compiler[0]})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
