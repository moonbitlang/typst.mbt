#!/usr/bin/env bash
# Fetch the Typst packages of the `packages` stage into
# `.repos/typst-packages`, pinned by tests/packages/manifest.tsv.
#
#   scripts/packages.sh [--check]
#
# For every line of the manifest (name, version, sha256, bytes, ...): the
# archive `<name>-<version>.tar.gz` of the official registry
# (https://packages.typst.org/preview/) is downloaded unless it is there,
# its size and SHA-256 must be the manifest's, and it is unpacked into
# `preview/<name>/<version>/` (the layout of Typst's package directories,
# so `--package-path .repos/typst-packages` serves them to a CLI too).
# Nothing else is fetched: the packages' own dependencies are lines of the
# manifest. A directory that the manifest does not list is an error (the
# stage must see exactly the pinned packages). `--check` only verifies what
# is there and fetches nothing.
#
# The packages are not part of this repository; their licences are in the
# manifest and in each package's `typst.toml`/`LICENSE`.
set -euo pipefail
cd "$(dirname "$0")/.."
manifest=tests/packages/manifest.tsv
dest=.repos/typst-packages
registry=https://packages.typst.org/preview
check=0
[ "${1:-}" = --check ] && check=1

sha256() {
  shasum -a 256 "$1" | cut -d' ' -f1
}

mkdir -p "$dest/preview" "$dest/.unpacked"
count=0
listed=" "
while IFS=$'\t' read -r name version sum bytes _; do
  case "$name" in '' | '#'*) continue ;; esac
  archive="$dest/$name-$version.tar.gz"
  if [ ! -f "$archive" ]; then
    if [ "$check" = 1 ]; then
      echo "packages.sh: $archive is missing" >&2
      exit 1
    fi
    curl -fsSL --retry 3 -o "$archive.part" "$registry/$name-$version.tar.gz"
    mv "$archive.part" "$archive"
  fi
  have_bytes=$(wc -c < "$archive" | tr -d ' ')
  have_sum=$(sha256 "$archive")
  if [ "$have_bytes" != "$bytes" ] || [ "$have_sum" != "$sum" ]; then
    echo "packages.sh: $archive is not the pinned archive:" >&2
    echo "  expected $bytes bytes, sha256 $sum" >&2
    echo "  found    $have_bytes bytes, sha256 $have_sum" >&2
    exit 1
  fi
  dir="$dest/preview/$name/$version"
  stamp="$dest/.unpacked/$name-$version-$sum"
  if [ ! -f "$stamp" ] || [ ! -f "$dir/typst.toml" ]; then
    rm -rf "$dir"
    mkdir -p "$dir"
    tar -xzf "$archive" -C "$dir"
    touch "$stamp"
  fi
  listed="$listed$name/$version "
  count=$((count + 1))
done < "$manifest"

for dir in "$dest"/preview/*/*/; do
  rel=${dir#"$dest/preview/"}
  rel=${rel%/}
  case "$listed" in
    *" $rel "*) ;;
    *)
      echo "packages.sh: $dir is not in $manifest" >&2
      exit 1
      ;;
  esac
done
echo "typst packages: $count in $dest"
