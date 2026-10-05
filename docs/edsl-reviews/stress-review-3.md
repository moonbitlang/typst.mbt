Fixes 1, 3, 4 and 5 are resolved. Fix 2 rejects empty selections and missing/mismatched enumerated cases, but coverage validation remains incomplete.

- **MAJOR — [tests/runner/edsl_suite.mbt:476](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/edsl_suite.mbt:476): disappeared cases escape validation.** After generation, removing `tests/edsl_gen/docs` silently drops its 757 cases; the remaining 3,792 retain their IDs and can pass. Manifest rows absent from enumeration are never checked. **Fix:** reconcile selected manifest identities against enumeration in both directions, rejecting unmatched rows and enumeration errors.

- **MAJOR — [tests/runner/edsl_stage.mbt:135](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/edsl_stage.mbt:135): unescaped content labels permit false structural equality.** `#metadata(([x<a>], [y<b>]))` and `#metadata(([x#label("a>, text@0(text: \"y\") <b")],))` produce the same structural encoding despite containing two versus one array items. Upstream query results differ; SVG/PDF/PNG bytes are identical. **Fix:** encode attached label names with `@library.repr_str`, and add this comparator regression.

- **MINOR — [doc/convert/rules.mbt:257](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/convert/rules.mbt:257): wrapper admits an escaping label return.** `#show heading: it => [#return <x>]; #heading[H]` becomes a wrapper that attaches the returned label inside `Markup`, producing an unattached-label warning and different output. The original displays the returned label without that warning. **Fix:** use `escapes(closure.body().to_untyped(), false, false)` so this rule falls back with its stream, as §4.5 requires.

Validation using existing binaries: 16 translator, 18 behavior—including the 2,000-argument regression—and 15 Prose tests passed. No fresh rebuild in the read-only workspace.

VERDICT: REQUEST CHANGES
