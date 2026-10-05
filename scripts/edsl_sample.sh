#!/bin/sh
# Regenerates the curated sample of translator output (doc/convert/sample):
# bench/long.typ and the showcase without its computed table
# (doc/convert/sample/showcase_static.typ: bench/showcase.typ minus the
# `fibs` lines, whose mutated variable makes the whole document one
# fragment), translated in the readable mode. The `edsl` stage compares
# both with their sources.
set -e
out=doc/convert/sample
moon run doc/convert/cli --target native -- "$out/showcase_static.typ" --prose --path=showcase.typ --name=showcase_static > "$out/gen_showcase.mbt"
moon run doc/convert/cli --target native -- bench/long.typ --prose --path=long.typ --name=long --no-using > "$out/gen_long.mbt"
moon fmt
