#!/usr/bin/env bash
# Fetch the Typst packages of the `packages` stage into
# `.repos/typst-packages`, pinned by tests/packages/manifest.tsv.
#
#   scripts/packages.sh [--check]
#
# For every line of the manifest (name, version, sha256, bytes, ...): the
# archive `<name>-<version>.tar.gz` of the official registry
# (https://packages.typst.org/preview/) is downloaded unless it is there,
# its size and SHA-256 must be the manifest's, and `preview/<name>/
# <version>/` (the layout of Typst's package directories, so `--package-path
# .repos/typst-packages` serves them to a CLI too) is made to be exactly
# what the archive contains: every archive is unpacked to a temporary
# directory and compared with the tree, which is replaced if it differs.
# Nothing else is fetched: the packages' own dependencies are lines of the
# manifest. Anything else in `.repos/typst-packages` (another namespace, a
# package, a version or an archive that the manifest does not list) is an
# error: the stage must see exactly the pinned packages.
#
# `--check` changes nothing and uses no network: a missing archive, or a
# tree that is not what its archive contains, is an error.
#
# The packages are not part of this repository; their licences are in the
# manifest and in each package's `typst.toml`/`LICENSE`.
set -euo pipefail
cd "$(dirname "$0")/.."
manifest=tests/packages/manifest.tsv
dest=.repos/typst-packages
registry=https://packages.typst.org/preview
check=0
case "${1:-}" in
  '') ;;
  --check) check=1 ;;
  *)
    echo "usage: scripts/packages.sh [--check]" >&2
    exit 2
    ;;
esac

fail() {
  echo "packages.sh: $*" >&2
  exit 1
}

sha256() {
  if command -v sha256sum > /dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

if [ "$check" = 1 ]; then
  [ -d "$dest/preview" ] || fail "$dest/preview is missing (run scripts/packages.sh)"
else
  mkdir -p "$dest/preview"
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
count=0
listed=" "
while IFS=$'\t' read -r name version sum bytes _; do
  case "$name" in '' | '#'*) continue ;; esac
  # The names become paths.
  case "$name$version" in
    *[!a-z0-9.-]* | .* | *..*) fail "bad name or version in $manifest: $name $version" ;;
  esac
  archive="$dest/$name-$version.tar.gz"
  if [ ! -f "$archive" ]; then
    [ "$check" = 0 ] || fail "$archive is missing (run scripts/packages.sh)"
    rm -f "$archive.part"
    curl -fsSL --retry 3 -o "$archive.part" "$registry/$name-$version.tar.gz"
    mv "$archive.part" "$archive"
  fi
  have_bytes=$(wc -c < "$archive" | tr -d ' ')
  have_sum=$(sha256 "$archive")
  if [ "$have_bytes" != "$bytes" ] || [ "$have_sum" != "$sum" ]; then
    echo "packages.sh: $archive is not the pinned archive (delete it to fetch it again):" >&2
    echo "  expected $bytes bytes, sha256 $sum" >&2
    echo "  found    $have_bytes bytes, sha256 $have_sum" >&2
    exit 1
  fi
  dir="$dest/preview/$name/$version"
  fresh="$tmp/$name-$version"
  mkdir "$fresh"
  tar -xzf "$archive" -C "$fresh"
  [ -f "$fresh/typst.toml" ] || fail "$archive has no typst.toml"
  if [ ! -d "$dir" ] || ! diff -r "$fresh" "$dir" > /dev/null 2>&1; then
    [ "$check" = 0 ] || fail "$dir is not what $archive contains (run scripts/packages.sh)"
    rm -rf "$dir"
    mkdir -p "$dest/preview/$name"
    cp -R "$fresh" "$dir"
  fi
  rm -rf "$fresh"
  listed="$listed$name/$version "
  count=$((count + 1))
done < "$manifest"

# Nothing but the pinned packages and their archives: no other namespace
# directory (a package namespace is an identifier, so hidden entries cannot
# be one), no other archive.
for entry in "$dest"/*; do
  [ -e "$entry" ] || continue
  case "$entry" in
    "$dest/preview") ;;
    *.tar.gz)
      rel=$(basename "$entry" .tar.gz)
      case "$listed" in
        *" ${rel%-*}/${rel##*-} "*) ;;
        *) fail "$entry is not in $manifest" ;;
      esac
      ;;
    *)
      [ ! -d "$entry" ] || fail "$entry does not belong there (only preview/ is a namespace of the stage)"
      ;;
  esac
done
for dir in "$dest"/preview/* "$dest"/preview/*/*; do
  [ -e "$dir" ] || continue
  rel=${dir#"$dest/preview/"}
  case "$rel" in
    */*)
      case "$listed" in
        *" $rel "*) ;;
        *) fail "$dir is not in $manifest" ;;
      esac
      ;;
    *)
      case "$listed" in
        *" $rel/"*) ;;
        *) fail "$dir is not in $manifest" ;;
      esac
      ;;
  esac
done
echo "typst packages: $count in $dest"
