#!/usr/bin/env python3
"""Pick the LFO phase offset for a mode whose colour is sampled once per frame.

`docs/PORTING-LADDER.md` §3.4: when a stock mode calls `color_picker_lfo` once
per frame, the port's colour is a pure function of time, and the verifier samples
it at a single instant while measuring *luma* only. If the sampled colour happens
to match the baseline colour (the palette's grey at `c = 0`) or the background's
luma, the colour knob reads dead — or the frame reads flat.

This prints the initial phase that keeps the sampled colour as far as possible
from *both* targets at every frame count the verifier uses.

Usage:
  tools/lfo_offset.py --inc 0.1 --calls 1
  tools/lfo_offset.py --inc 0.003 --calls 6 --bg 0.15
  tools/lfo_offset.py --step 0.009

`--inc` is `(knob-0.5)*2*inc_amt` for the `knob4 = 1.0` probe (stock's
`inc_amt` is 0.1 unless the mode passes its own), `--calls` is how many times the
mode calls the picker per frame; the per-frame step is `calls * inc * 30 / 60`
(stock's 30 fps re-timed to our 60). `--bg` is the background phase the mode feeds
the background picker (0.15 for the pack's remapped baseline).
"""
import argparse
import math

FRAMES = (60, 130, 300, 600)
EVENT_FRAME = 5          # the verifier applies a knob change at frame 5
PALETTE_GREY = 0.5       # picker(0) = (0.5, 0.5, 0.5) — the baseline colour


def picker(c):
    return (0.5 + 0.5 * math.sin(2 * math.pi * c),
            0.5 + 0.5 * math.sin(4 * math.pi * c),
            0.5 + 0.5 * math.sin(8 * math.pi * c))


def luma(rgb):
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def bg_luma(phase):
    return luma(((1 - (math.cos(3 * math.pi * phase) * 0.5 + 0.5)) * phase,
                 (1 - (math.cos(7 * math.pi * phase) * 0.5 + 0.5)) * phase,
                 (1 - (math.cos(11 * math.pi * phase) * 0.5 + 0.5)) * phase))


def sampled(offset, step, frames):
    x = (offset + step * (frames - EVENT_FRAME)) % 2
    return x if x <= 1 else 2 - x


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--inc', type=float, help='per-call index step at knob4 = 1.0')
    parser.add_argument('--calls', type=int, default=1, help='picker calls per frame')
    parser.add_argument('--step', type=float, help='per-frame phase step (overrides --inc)')
    parser.add_argument('--bg', type=float, default=0.15, help='background picker phase')
    parser.add_argument('--frames', default=','.join(str(f) for f in FRAMES))
    args = parser.parse_args()

    if args.step is not None:
        step = args.step
    elif args.inc is not None:
        step = args.calls * args.inc * 30 / 60
    else:
        parser.error('need --inc (with --calls) or --step')

    frames = tuple(int(f) for f in args.frames.split(','))
    grey = PALETTE_GREY * 255
    bg = bg_luma(args.bg) * 255

    best = []
    for i in range(1, 100):
        offset = i / 100
        worst = min(min(abs(luma(picker(sampled(offset, step, f))) * 255 - grey),
                        abs(luma(picker(sampled(offset, step, f))) * 255 - bg))
                    for f in frames)
        best.append((worst, offset))
    best.sort(reverse=True)
    worst, offset = best[0]

    print(f'step {step:.6f} per frame   baseline grey {grey:.2f}   background {bg:.2f}')
    print(f'offset {offset:.2f}  worst-case clearance {worst:.2f} luma units')
    for _, off in best[:3]:
        lumas = [round(luma(picker(sampled(off, step, f))) * 255, 1) for f in frames]
        print(f'  candidate {off:.2f}: sampled lumas at {"/".join(str(f) for f in frames)}'
              f' = {lumas}')
    if worst < 20:
        print('WARNING: no offset clears both targets well at these frame counts — '
              'the mode may need a geometry or colour deviation instead')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
