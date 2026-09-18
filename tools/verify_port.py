#!/usr/bin/env python3
"""Run the port contract gate for a mode in this pack.

`tools/scene_verify.py` (in the engine repo) needs the engine's shared libraries
and `xvfb-run`, neither of which the workstation has, so the gate runs inside the
build image with this pack mounted as `/factory`. This wrapper keeps that
invocation in one place — `docs/PORTING-LADDER.md` documents it — and prints the
numbers a port report cites.

Usage:
  tools/verify_port.py <slug> [--frames 300] [--run N] [--quiet]

Evidence lands in `local/verify-<slug>[-N]/` (gitignored). The output directory
must not exist; `--run` picks the suffix explicitly, otherwise the next free one
is used. Exit 0 iff the verdict passes.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT.parent / 'eyesy'
IMAGE = 'localhost/eyesy-build:bookworm'
KNOBS = (1, 2, 3, 4, 5)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pick_output(slug, run):
    """local/verify-<slug>[-N] for the first free N (or the requested one)."""
    local = ROOT / 'local'
    if run is not None:
        return local / f'verify-{slug}-{run}'
    first = local / f'verify-{slug}'
    if not first.exists():
        return first
    suffix = 2
    while (local / f'verify-{slug}-{suffix}').exists():
        suffix += 1
    return local / f'verify-{slug}-{suffix}'


def command(slug, frames, output):
    return [
        'podman', 'run', '--rm', '--init', '--arch', 'amd64', '--userns=keep-id',
        '-v', f'{ENGINE}:/workspace', '-v', f'{ROOT}:/factory', '-w', '/workspace',
        '-e', 'LD_LIBRARY_PATH=/workspace/engine/bin', IMAGE,
        'python3', 'tools/scene_verify.py', '--modes-root', '/factory',
        '--mode', slug, '--output', f'/factory/{output.relative_to(ROOT)}',
        '--frames', str(frames), '--xvfb',
    ]


def markdown(summary, slug):
    """The verification section of a port report, ready to paste."""
    stats = summary.get('grab_stats', {})
    diffs = summary.get('ab_diffs', {})
    audio = summary.get('audio', {})
    trigger = summary.get('trigger') or {}
    lines = [
        f'`python3 tools/verify_port.py {slug} --frames '
        f'{summary.get("frames_per_run")}` → `"verdict": "{summary.get("verdict")}"`. '
        f'Software GL (llvmpipe), {summary.get("frames_per_run")} frames/run, engine '
        f'sha256 `{summary.get("engine_sha256", "")[:12]}…`.',
        '',
        '| Check | Result |',
        '| --- | --- |',
        f'| determinism | mean {summary.get("determinism", {}).get("mean")}, '
        f'frac {summary.get("determinism", {}).get("frac")} |',
    ]
    for knob, name in sorted(summary.get('params', {}).items(), key=lambda kv: int(kv[0])):
        d = diffs.get(f'knob{knob}', {})
        cells = ', '.join(f'{tag} {d[tag]["frac"]:.4f}' for tag in ('mid', 'max') if tag in d)
        lines.append(f'| knob {knob} `{name["name"]}` | {cells or "n/a"} |')
    if audio.get('diffs'):
        cells = ', '.join(f'{tag.replace("audio-", "")} {m["frac"]:.4f}'
                          for tag, m in audio['diffs'].items())
        lines.append(f'| audio | {cells} (threshold {audio.get("threshold")}) |')
    lines.append(f'| trigger | {trigger.get("pass")} '
                 f'{"— " + trigger["note"] if trigger.get("note") else ""} |')
    lines.append(f'| luma bounds | mean {min((s["mean"] for s in stats.values()), default=None)}'
                 f'–{max((s["mean"] for s in stats.values()), default=None)}, '
                 f'min stddev {min((s["stddev"] for s in stats.values()), default=None)} |')
    lines.append(f'| `p50_ms` (software GL) | {summary.get("final", {}).get("p50_ms"):.1f} '
                 f'(resources {summary.get("final", {}).get("resources")}) |')
    if summary.get('failures'):
        lines += ['', 'Failures: ' + '; '.join(summary['failures'])]
    return '\n'.join(lines)


def report(summary, slug, before, after):
    stats = summary.get('grab_stats', {})
    diffs = summary.get('ab_diffs', {})
    knobs = {k: max((m['frac'] for m in v.values()), default=0.0) for k, v in diffs.items()}
    audio = summary.get('audio', {})
    print(json.dumps({
        'mode': slug,
        'verdict': summary.get('verdict'),
        'failures': summary.get('failures', []),
        'sha256_unchanged': before == after,
        'sha256': before,
        'determinism': summary.get('determinism'),
        'knob_frac': {f'knob{k}': round(knobs.get(f'knob{k}', 0.0), 5) for k in KNOBS},
        'audio': {v: round(m['frac'], 5) for v, m in (audio.get('diffs') or {}).items()},
        'audio_pass': audio.get('pass'),
        'trigger_pass': (summary.get('trigger') or {}).get('pass'),
        'min_stddev': min((s['stddev'] for s in stats.values()), default=None),
        'luma_range': [min((s['mean'] for s in stats.values()), default=None),
                       max((s['mean'] for s in stats.values()), default=None)],
        'p50_ms': (summary.get('final') or {}).get('p50_ms'),
        'evidence': str(summary.get('_dir', '')),
    }, indent=1))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('slug')
    parser.add_argument('--frames', type=int, default=300)
    parser.add_argument('--run', type=int, default=None,
                        help='output suffix; default: the next free one')
    parser.add_argument('--quiet', action='store_true',
                        help='suppress the verifier stdout (one JSON line per run)')
    parser.add_argument('--markdown', action='store_true',
                        help='print the port report verification section instead of JSON')
    args = parser.parse_args()

    mode = ROOT / args.slug
    if not (mode / 'main.lua').is_file():
        sys.exit(f'no such mode in this pack: {mode}/main.lua')
    verifier = ENGINE / 'tools/scene_verify.py'
    if not verifier.is_file():
        sys.exit(f'engine repo not found at {ENGINE} (expected {verifier})')

    output = pick_output(args.slug, args.run)
    if output.exists():
        sys.exit(f'output directory already exists: {output}')
    main_lua = mode / 'main.lua'
    before = digest(main_lua)

    result = subprocess.run(command(args.slug, args.frames, output),
                            capture_output=True, text=True)
    if not args.quiet and result.stdout:
        print(result.stdout.strip())
    if result.returncode != 0 and result.stderr:
        print(result.stderr.strip(), file=sys.stderr)

    summary_path = output / f'00-{args.slug}' / 'summary.json'
    if not summary_path.is_file():
        sys.exit(f'verifier produced no summary at {summary_path} '
                 f'(exit {result.returncode})')
    summary = json.loads(summary_path.read_text())
    summary['_dir'] = str(summary_path.parent.relative_to(ROOT))
    if args.markdown:
        print(markdown(summary, args.slug))
    else:
        report(summary, args.slug, before, digest(main_lua))
    return 0 if summary.get('verdict') == 'pass' else 1


if __name__ == '__main__':
    raise SystemExit(main())
