#!/usr/bin/env python3
"""Prints Rust sources without doc comments, stopping at #[cfg(test)]."""
import sys
for path in sys.argv[1:]:
    print('=====', path)
    for line in open(path):
        s = line.strip()
        if s.startswith('#[cfg(test)]'):
            break
        if s.startswith('///') or s.startswith('//!'):
            continue
        sys.stdout.write(line)
