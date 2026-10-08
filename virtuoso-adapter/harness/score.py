#!/usr/bin/env python3
"""Rule2DRC Virtuoso adapter - scorer.

Compares a candidate result file against a golden file.
Both files: one "x1 y1 x2 y2" (integer DBU) per line.

Usage:
    python3 harness/score.py <candidate.txt> <golden.txt>

Reports TP / FP / FN, precision, recall, F1. Exit 0 on perfect match.
"""
import sys


def load(path):
    boxes = set()
    with open(path) as f:
        for ln, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) != 4:
                raise ValueError(f"{path}:{ln}: want 4 ints, got {line!r}")
            boxes.add(tuple(int(p) for p in parts))
    return boxes


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    cand = load(sys.argv[1])
    gold = load(sys.argv[2])
    tp = cand & gold
    fp = cand - gold
    fn = gold - cand
    precision = len(tp) / len(cand) if cand else 1.0
    recall = len(tp) / len(gold) if gold else 1.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    print(f"candidate={len(cand)} golden={len(gold)}")
    print(f"TP={len(tp)} FP={len(fp)} FN={len(fn)}")
    print(f"precision={precision:.3f} recall={recall:.3f} F1={f1:.3f}")
    for b in sorted(fp):
        print(f"  FP {b[0]} {b[1]} {b[2]} {b[3]}")
    for b in sorted(fn):
        print(f"  FN {b[0]} {b[1]} {b[2]} {b[3]}")
    return 0 if (not fp and not fn) else 1


if __name__ == "__main__":
    sys.exit(main())
