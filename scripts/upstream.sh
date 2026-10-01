#!/usr/bin/env bash
# Fetch the pinned upstream Typst checkout into .repos/typst.
set -euo pipefail
cd "$(dirname "$0")/.."
REV=$(cat UPSTREAM_REV)
if [ ! -d .repos/typst/.git ]; then
  git clone https://github.com/typst/typst.git .repos/typst
fi
git -C .repos/typst fetch -q origin
git -C .repos/typst checkout -q "$REV"
echo "upstream typst at $(git -C .repos/typst rev-parse --short HEAD)"
