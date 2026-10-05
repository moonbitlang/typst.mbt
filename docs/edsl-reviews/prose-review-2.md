Direct string checks, CR/CRLF, origins, Show coverage, and the documented capacity policy resolve those parts of review 1. Remaining findings:

- **MAJOR — [doc/lower.mbt:450](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/lower.mbt:450): decoded placeholders still reach output.** Given `s = "\{Emph("x")}"`, `Call("eval", positional=[Value::str(@library.repr_str(s))])` passes checking because its source contains escaped delimiters. Evaluation restores the placeholder, whose result is displayed unchecked. `Markup` has the same unchecked-result path. **Fix:** validate engine results recursively before displaying or forwarding them, including strings inside values/content; add this regression case.

- **MINOR — [doc/debug.mbt:99](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/debug.mbt:99), [doc/debug.mbt:157](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/debug.mbt:157): Debug silently discards semantic inputs.** Calls to `"emph"` and `"strong"` with identical arguments print identically; generic `Set` loses its target too. `Markup("#x", scope=[("x", …)])` hides the scope entirely. These snapshots miss meaningful regressions. **Fix:** include generic call/set targets and evaluation scopes; include `Document.dir` in its representation.

- **MINOR — [doc/prose.mbt:50](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/prose.mbt:50): allocation still lacks an exhaustion guard.** At ID `10^18`, emitted tokens exceed the parser’s 18-digit limit and escape leak detection; eventually `Int64` wraps. Astronomical, but contrary to “never reused.” **Fix:** reject allocation before `10^18`, and test the boundary by seeding the counter.

- **MINOR — [doc/prose.mbt:251](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/prose.mbt:251): consumed tokens can be misreported as evicted.** Consume token 0, then cause token 1 to be evicted; reusing token 0 now reports capacity loss. The cutoff cannot distinguish consumption from eviction. **Fix:** use an honest “consumed or dropped” message below the cutoff, document it, and test this sequence.

- **MINOR — [docs/edsl-design.md:398](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/docs/edsl-design.md:398): `Lit(data)` is not a complete reserved-token escape.** If `data` matches an issued token, lowering still rejects it. **Fix:** explicitly state that `Lit` protects literal delimiters, but complete issued-token spellings remain unrepresentable.

Existing binaries passed all 10 Prose/Debug tests and the `prose` twin; no fresh rebuild.

VERDICT: REQUEST CHANGES
