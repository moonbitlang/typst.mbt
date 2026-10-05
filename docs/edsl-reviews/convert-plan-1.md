The draft needs a fundamental change to its fallback model. **EDSL descriptions are deferred computations, not evaluated Typst values**, so copying definitions into preludes or passing a translated continuation through `scope` does not generally preserve evaluation order, binding identity, or diagnostics.

The text-merging rule and existing converted-mode normalizer also sacrifice useful bug detection. I would implement the following replacement design.

1. **Define conversion units and reproduce their worlds first.**

   Use a shared corpus descriptor:

   ```text
   CaseId       = (corpus, relative_file, case_name, ordinal)
   SourceUnit   = { id, source_text, source_file_id, attributes, source_hash }
   WorldProfile = { roots, packages, library, features, fonts, date, inputs }
   ```

   For suite cases, reuse `split_tests` and `strip_notes`. The conversion input is the stripped **case body**, not the containing `.typ` file. Preserve the original virtual filename, `tests/suite/<relative-file>`, for resource resolution. Do not look up cases by name alone. See [collect.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/collect.mbt:64).

   Factor the existing test-world construction into shared runner support. Both paths need `test_library()`, `parse_features`, the test fonts, fixed date, package loader, test globals, and small-page styles. `DocWorld::in_memory` and the bench twin world are not substitutes. Also use `is_paged`: upstream paged selection includes `paged`, `pdf`, and `pdftags`, including parameterized attributes. Preserve the existing stage-specific `// SKIP` handling. See [test_world.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/test_world.mbt:253) and [paged_stage.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/paged_stage.mbt:8).

   **The documentation corpus needs its own adapter.** These are not 72 independent ordinary documents:

   - `docs/main.typ` imports `@typst/docs:0.0.0`.
   - Component files export functions and can produce empty content when evaluated alone.
   - Documentation uses the custom `stdx` module, custom elements/functions, package mappings, and additional rendering rules supplied by upstream’s [docs/src/world.rs](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/.repos/typst/docs/src/world.rs:199).

   Inventory all 72 files, but distinguish document entry points, included chapters, and library modules. Record missing world support as an infrastructure blocker. Empty module-content equality must not count as exercising its exported functions. Add invocation fixtures or documentation-entry-point coverage for those modules.

2. **Generate an API description that distinguishes three different interfaces.**

   Extend `docgen.py`, but export separate signatures for:

   ```text
   ApiEntry {
     typst_path,
     constructor?,
     set_constructor?,
     selector?,
     result_kind,
     parameters,
     constructor_argument_order,
     set_argument_order,
     selector_fields,
     signature_adapter,
   }

   Parameter {
     typst_name,
     moonbit_name,
     moonbit_type,
     conversion_kind,
     typst_argument_kind,
     moonbit_argument_kind,
     required_by_typst,
     required_by_edsl,
     extra_policy,
     accepted_states,
     source_role,
   }
   ```

   `conversion_kind` must distinguish types that have the same MoonBit representation: for example, `String → Str` versus `String → Label`, and ordinary strings versus resource paths.

   The draft’s single parameter-kind field is insufficient. Existing examples include:

   - `EnumItem(body, number?)`: MoonBit order differs from Typst positional order.
   - `Block(body)`: EDSL requires a body although Typst permits omission.
   - `Link(dest, body?)`: special optional-body handling.
   - `Text`: custom construction and positional shorthands.
   - `Equation`: handwritten constructor, generated set rule and selector.
   - Selectors expose only a subset of constructor fields.

   These distinctions already appear in `params_of`, `emit_element`, reviewed `ELEMENTS` entries, and `emit_function` in [docgen.py](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/scripts/docgen.py:529).

   Include reviewed metadata for handwritten facades—gradients, `Equation`, selectors—not just generated elements. Unknown paths remain eligible for T2; the table need not enumerate every standard-library function.

   Version the table and record its hash. Test emitted examples against the public EDSL interface. Store generator tables using the repository’s static-table conventions.

3. **Translate into an intermediate representation before emitting MoonBit.**

   Suggested judgments:

   ```text
   Γ; phase ⊢ markup-stream ⇒ ContentIR
   Γ; phase ⊢ expression ⇐ FacadeType ⇒ TypedIR
   Γ; phase ⊢ expression ⇒ ValueIR
   Γ; phase ⊢ statement-stream ⇒ StreamIR
   ```

   `phase` distinguishes initial lowering, show/context callbacks, and other callbacks. `Γ` maps **binding identities**, not just names, to representations and capabilities.

   Every result carries:

   ```text
   Facts {
     free_bindings,
     writes,
     may_fail,
     may_warn,
     reads_context,
     reads_world,
     creates_identity,
     control_flow,
     source_dependence,
   }
   ```

   Treat unknown facts conservatively. A static type alone does not justify moving, duplicating, or deleting an expression.

   Preserve source ranges as UTF-8 byte ranges. Use AST accessors for semantic traversal and the CST/source for exact slices. In particular, `Markup::exprs()` suppresses certain newlines after statements; iterating raw children and handling whitespace yourself would be wrong. See [syntax/ast/markup.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/syntax/ast/markup.mbt:30).

   Reject speculative translation of malformed ASTs: accessors deliberately return placeholders. Syntax-error cases should retain the original source in a fallback, including diagnostics from otherwise unreachable code.

4. **Mirror markup structure; remove the text-merging optimization.**

   Emit one description per evaluator expression:

   - Text → `Lit(text)` or an equivalently distinct origin-bearing string.
   - Space → `Space()` or `Space::newline()`, **directly from `had_newline()`**.
   - Smart quote → `Smartquote(double=...)`.
   - Paragraph break → `Parbreak()`.
   - Heading → `Heading(body, depth=...)`.
   - List/enum/term syntax → item siblings, preserving intervening spaces and paragraph breaks.
   - Raw → decoded `lines().join("\n")`, explicit `block`, optional language.
   - Label → a label-valued inserted expression, preserving its sequence position.
   - Equation → its math-body source plus `block()` and the required scope.

   Do not infer paragraph or list containers. The handwritten [bench twins](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/twins/bench.mbt:1) are author-written equivalents for particular documents; they are not a generally valid lowering specification.

   The evaluator keeps text and spaces distinct. A rule such as `show text: it => box(stroke: red, it)` can observe whether `a b` consists of two text elements or one. Newline-space behavior also depends on realized neighbors, including show-rule results, not just adjacent AST nodes. See [eval/markup.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/markup.mbt:15) and [realize/spaces.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/realize/spaces.mbt:116).

   Another missing distinction: escapes and shorthands evaluate to `Symbol`, whose display creates `SymbolElem`, rather than ordinary text. Translating them directly to strings loses observable structure before realization. Use a faithful value construction or fallback; report a missing typed symbol facility as an EDSL gap. See [eval/code.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/code.mbt:78).

5. **Make typed and T2 translation preserve evaluation, not merely argument values.**

   Several draft rules need tightening:

   **Argument order.** `eval_args` evaluates arguments in source order. Generated constructors assemble arguments in signature order; `Value::call` assembles positional arguments before named arguments. Reordering two failing expressions can change the first reported error. Hoisting their description construction into MoonBit `let`s does not solve this: evaluation happens later in `Lower::args`. See [eval/call.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/call.mbt:329), [doc/value.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/value.mbt:186), and [doc/lower.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/lower.mbt:340).

   Initially permit reordered arguments only when the reordered expressions are proven total and effect-free. Otherwise retain the whole call as source. Add an ordered-argument EDSL hatch later if coverage measurements justify it.

   **`extra` is not universal.** It replaces optional positional fields, but a required positional field is not supplied by naming it in `extra`. For an unsupported required argument, use a faithful generic call or fallback. Do not invent a dummy typed argument. Preserve omitted versus explicit `none` versus empty content.

   **Bindings.** This is unsound:

   ```text
   Typst:   let x = f(); ... x ... x
   MoonBit: let x = Value::call("f"); ... x ... x
   ```

   The latter may call `f` twice; an unused binding may never call it. Initially translate bindings only when their values are demonstrably total, immutable, and identity-free. Content and function-producing bindings require additional care. `Lower::value` has no general evaluated-binding cache. See [doc/lower.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/lower.mbt:407).

   **Code joins and loops.** `eval_code_exprs` and `eval_for_loop` accumulate with `library.join`; `Seq` uses `Content::sequence`. These differ: joining content concatenates sequence children, whereas `Seq` preserves nesting. Thus “loop pushes bodies into an array, then `Seq`” is not a general translation. Preserve join semantics for a narrowly proven subset; otherwise fallback. See [eval/code.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/code.mbt:14), [eval/flow.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/flow.mbt:106), and [library/ops.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/library/ops.mbt:70).

   Preserve empty results of statements where they participate in markup sequence structure.

   **Arithmetic and methods.** Do not use MoonBit arithmetic/string operations merely because types line up. Overflow, division, string ordering, Unicode iteration, short-circuiting, and diagnostics need Typst semantics. The existing length facade is useful because its operators lower through Typst operators. Method-to-type-scope rewriting needs an audited method entry and a proven receiver type; `eval_field_callee` distinguishes methods, associated functions, dictionary fields, and element-specific methods.

6. **Replace prelude replay with conservative, scope-contained fallback regions.**

   The minimal sound rule set should be:

   **a. No general prelude reconstruction.** Do not copy referenced definitions into every fragment. Preserve definitions in their original execution order inside one region.

   For example:

   ```typst
   #let x = 1
   #let f() = x
   #let x = 2
   #f()
   ```

   Rebuilding `f` under the later `x` changes its capture. Typst captures binding values at closure construction, and named defaults are also evaluated then. See `eval_closure_expr`, `CapturesVisitor`, and [Binding::capture](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/library/scope.mbt:327).

   **b. A fallback has no escaping bindings or control flow.** Its writes, definitions, imports, and `break`/`continue`/`return` must remain within it. Otherwise enlarge to an enclosing scope or control-flow construct, potentially the whole file.

   **c. Incoming scope values must be safe to materialize at the boundary.** Initially allow immutable literal/value trees with proven equivalent construction. Do not pass an unevaluated call description as though it were an already evaluated binding.

   **d. Preserve complete rule tails.** An unsupported set/show rule captures its remaining stream within the original block. Do not cut the region at the next statement. Preserve the distinction between code-stream joining and markup-stream sequencing.

   **e. Preserve label attachment boundaries.** A fallback must not hide a label that should attach to content outside it, nor turn several markup siblings into one newly labelable sequence. Enlarge the region when necessary.

   **f. Imports and mutation are barriers.** Retain import execution, aliases, wildcard bindings, package identity, and consumers together. “Definition through last textual use” is insufficient: captured closures, aliases, nested functions, and exported values can extend the dependency.

   **g. Validate fragment grammar.** Preserve the original parsing mode and delimiters. A code expression’s source slice generally excludes markup’s `#`; a content block and its body are different slices.

   **h. Never silently downgrade a semantic mismatch.** Widening a fallback is allowed during planning because a proof obligation failed. Once generated code disagrees at runtime, retain that candidate as a bug artifact.

   Whole-file `Markup` is the initial fallback baseline, subject to the source/world limitations below. Smaller regions are introduced only with focused boundary tests.

   **The proposed continuation is not generally sound.** `Lower::eval` lowers every `scope` value before evaluating the snippet. Therefore:

   ```typst
   #show: panic("rule")
   #panic("tail")
   ```

   reports the rule error originally, but a pre-lowered `body` can report the tail error first. Similar changes affect warnings and identity creation. See [Lower::eval](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/lower.mbt:548).

   Permit continuation holes only after proving that moving their lowering before the rule is observationally harmless. Do not implement a general continuation mechanism in the first version.

7. **Treat value fallback and source context as explicit EDSL gaps.**

   `Value::call("eval", ...)` is **not** equivalent to evaluating the expression in its current context. Native `eval` creates an empty introspector and uses `Context::none()`. `Markup`, by contrast, calls mapped evaluation with its lowering context. Both string-evaluation paths also differ from source evaluation in route handling. See [library/eval_funcs.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/library/eval_funcs.mbt:57) and [eval/lib.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/lib.mbt:107).

   Consequently:

   - Use native `eval` only for a restricted expression proven independent of those differences.
   - Otherwise widen to a content fallback containing the original context/control-flow construct.
   - If small value fallbacks are important later, add a reviewed mapped code-value facility that preserves the invocation context and specifies route behavior. Count it as T3.

   **Do not solve paths by rewriting only typed string literals.** That misses dynamic paths, generic calls, raw themes/syntaxes, CSL paths, imports, and byte-backed SVG dependencies. Rewriting can also change stored source values and error messages.

   Introduce an explicit source-context requirement:

   ```text
   SourceContext {
     virtual_root,        // Project or Package(spec)
     original_file,
     resolution_base,
     source_map,
   }
   ```

   A subsequent EDSL extension should anchor synthetic origins/snippets in the correct virtual root and directory while preserving source strings. It must also specify self-import/cycle behavior and route handling. Merely changing the OS world root breaks project-absolute and package-relative semantics. `PathOrStr::resolve` derives both root and base from the argument’s file ID. See [library/path.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/library/path.mbt:77).

   Until supported, affected cases receive a precise T4/source-context reason. A flagged wrong path must not remain a supposedly valid T3 conversion.

8. **Use a stricter comparison contract, with narrowly identified provenance normalization.**

   | Semantic issue | Required treatment |
   |---|---|
   | Text segmentation, spaces, smart quotes, symbols | Mirror the evaluator. Do not normalize resulting behavioral differences away. |
   | Implicit paragraphs and list grouping | Preserve markup items and breaks. Explicit containers can change show rules, grouping, and tags. |
   | Labels and nested sequences | Preserve attachment target and sequence boundaries exactly. |
   | Set/show scope and document settings | Preserve rule-tail structure, order, and `liftable` behavior. Do not hoist document rules into a configuration object. |
   | Callback re-emission | Re-emit the original view, including its guards/prepared state. Reconstructing the element can retrigger rules. |
   | Spans and glyph source offsets | Omit concrete provenance from comparison; retain it in debugging artifacts. |
   | Location/hash values | Canonicalize opaque identities consistently, preserving references, equality relationships, tag pairing, and ordering. |
   | Memoization/convergence | Differences are bugs to investigate, not normalizer exceptions. |
   | Source identity exposed as ordinary output | Do not erase strings or pixels. Preserve it through an extension, or report an expressiveness limitation. |

   Document settings are visited during realization. `visit_styled` populates document information/options and rejects rules inside containers; `visit_show_rules` also changes the `outside` state. Extra wrappers can therefore change results even when the visible body looks equivalent. See [realize/realize.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/realize/realize.mbt:588).

   Raw location hashes will legitimately differ: content fingerprints include spans and fields; preparation derives location keys from content; locators combine keys and disambiguators. Host and Typst functions also have different fingerprint representations. Compare relationships, not raw hashes. However, changes to query results, measurement stabilization, links, counter/state order, or convergence remain substantive failures. See [library/value_hash.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/library/value_hash.mbt:252) and [library/locator.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/library/locator.mbt:134).

   **Do not adopt `tag_names_only` as the suite oracle.** It drops all tag fields, conflates elements with the same plain name, and additionally removes list/enum/term-item tags. That accommodation exists for the handwritten bench conversions. See [FrameEncoder::skips](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/frame_dump.mbt:233).

   Reuse and extend `StructDumper` to preserve element identity, labels, stored fields, styles, and nested values in frame tags. Function-body equivalence cannot be proved by `repr`; record that limitation and test behavior. Any further normalization must have a named rationale and a regression proving that it does not conceal the intended bug class.

9. **Compare outcomes at every applicable phase.**

   For each case, collect:

   ```text
   EvaluationOutcome = Success(normalized_content) | Failure(diagnostics)
   CompileOutcome    = Success(normalized_frames)  | Failure(diagnostics)
   ExportOutcome     = Success(artifact)           | Failure(diagnostics)
   ```

   Compare success/failure status, error messages, warning messages, and ordered hints. Compare diagnostic multiplicity; do not deduplicate by message after stripping spans.

   The current `check_pair` cannot handle expected failures: its Typst-error branch always records a failure, even if the EDSL produced the same errors. Its structural-success branch also does not provide the required complete evaluation diagnostic comparison. See [edsl_stage.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/edsl_stage.mbt:265).

   Diagnostic deduplication itself is span-sensitive: `typst.deduplicate` keys on `(span, message)`. Preserve distinct source occurrences in generated origins so two warnings do not accidentally collapse. Ignore concrete spans in the final comparison; report location-presence differences separately unless they are explicitly part of the gate.

   For all cases, compare evaluation diagnostics and successful lowered content. **Diagnostics alone make non-paged tests too weak:** a converter that returns empty content can pass many such cases.

   For paged cases:

   - Compile both sides with memoization on and off.
   - Compare EDSL versus evaluator in each mode.
   - Also compare each side against itself across modes.
   - Compare SVG, PDF bytes, and PNG dimensions/pixels with identical resolved options, fonts, inputs, and date settings.
   - Compare export failures and warnings instead of treating every export failure as a harness failure.

   Keep raw artifact equality as requested. Canonicalized SVG/PDF analysis may explain a failure but should not silently turn it into a pass.

   The primary reference here is the **MoonBit evaluator path**. Existing Rust-oracle stages establish its upstream parity separately; upstream PDF byte identity is not this repository’s goal.

10. **Restrict host-callback translation and make tier accounting honest.**

   Initially translate only callbacks with immutable captures, supported field accesses, equivalent evaluation timing, and no nested callback creation.

   The existing session rejects callbacks created during compilation with `callbacks cannot be created inside a callback`. A translated nested `context` or show rule can hit this even when its Typst original works. Keep such constructs inside source fallback; report the restriction separately. See [Session::host](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/session.mbt:91).

   Do not automatically replace a native function used as a show transformer with a host wrapper: its representation and diagnostics may differ. Similarly, selector-less `show` is immediate recipe application, whereas selected show rules are retained for realization. See [eval/code.mbt](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/eval/code.mbt:67).

   Determine tiers from generated mechanisms:

   - **T1:** typed facilities only.
   - **T2:** any value/generic hatch, without source evaluation.
   - **T3:** any source-evaluation fragment, including code-mode `eval`.
   - **T4:** no conversion satisfying the current contract, with a concrete reason.

   Under the requested definition, math emitted through `Equation(source)` contributes T3. Report “math-only T3” separately so it does not obscure ordinary translation progress. A `Value::call("eval", ...)` must not be mislabeled T2.

   Keep tier separate from correctness. A T1 candidate can fail; a T3 whole-file fallback can pass while exercising almost no typed lowering.

11. **Keep batching, but break the generator/build dependency cycle.**

   A runner that imports generated packages cannot execute `edsl-convert` after generated code stops compiling. Build a conversion executable whose dependency graph excludes generated packages, or build and retain that executable before generation. A runner subcommand can dispatch to that independent tool.

   The pure package boundary should be:

   ```text
   doc/convert: SourceUnit + API metadata → generated source + manifest
   runner/tool: corpus discovery, filesystem writes, compiler invocation
   shared test support: worlds, descriptors, registry, comparison
   ```

   Generated packages must not import the executable runner to call `register`; use a separate registry/support package.

   `fn init` registration is acceptable with constraints:

   - Register metadata and builder function references only.
   - Do not build documents, read files, or compile during initialization.
   - Do not depend on registration order.
   - Sort by stable case ID before execution.
   - Reject duplicate IDs and verify the registry against the manifest.
   - Ensure shard packages are explicitly imported and exercised.

   Shard by generated size and measured compiler cost, not only suite directory. Runtime filtering does not reduce compile-time memory. Begin with one suite executable, but permit a bounded number of shard executables if whole-program build memory demands it.

   Generate stable legal symbols such as `build_<digest>` from the full case ID. Keep human names in metadata. Replacing punctuation with underscores is collision-prone.

   Preserve `#callsite(autofill)` by emitting real constructor calls and explicit type annotations where needed. Use `Content(...)` to unify heterogeneous branches. Keep a source map from generated ranges to original AST ranges. Avoid routing all nodes through one helper call site; plain strings in one array already share an argument origin. Do not add iteration keys indiscriminately, because repeated execution of one Typst AST site normally reuses its source span.

   For compiler recovery:

   - Preserve the first candidate and compiler diagnostics.
   - Attribute errors to cases through the generated-source map.
   - Regenerate affected candidates as fallback only to keep the sweep runnable.
   - Record the original compile failure permanently.
   - Bisect ambiguous shard-wide failures; classify compiler crashes/OOM separately.
   - Check the replacement again.

   A successful fallback rebuild does not erase a translator compile bug. Use atomic generation, stale-file cleanup, input/API hashes, and bounded recovery attempts.

12. **Implement in an order that produces interpretable failures.**

   Start with this sequence:

   1. Shared corpus/world descriptors and the corrected outcome comparator.
   2. Whole-file fallback baseline on the suite, exposing path, route, and environment gaps.
   3. Exact markup translation: spaces, quotes, raw, headings, item grouping, labels, and equation scope.
   4. Typed literal arguments and straightforward constructors.
   5. Ordered T2 calls, typed set rules, and simple show-set/selectors.
   6. Restricted host callbacks and context operations.
   7. Closed immutable bindings and narrowly verified code constructs.
   8. Smaller fallback regions, guided by measured coverage.
   9. Documentation-world support and module invocation fixtures.

   Seed boundary regressions for argument-error order, unused failing bindings, closure capture before rebinding, CJK newline spaces after show transformations, labels across sequence boundaries, nested document rules, and callbacks created inside callbacks.

   The final per-document table should contain:

   | Area | Measurements |
   |---|---|
   | Identity | Corpus, file, case name, attributes, source/API/world hashes |
   | Coverage | Tier; typed/T2 node counts; math-only versus other T3; imported code left to evaluation |
   | Fallback | Original byte ranges, construct kinds, reasons, region expansion reasons |
   | Ratios | Union of fallback source bytes/source bytes; copied/generated source bytes separately |
   | Compilation | First-attempt status, recovery status, compiler error category |
   | Evaluation | Status, diagnostic equality, structural equality |
   | Layout | Frame equality in each memo mode; cross-mode equality |
   | Export | SVG, PDF, PNG, and export-diagnostic results independently |
   | Cost | Generated bytes, generation/check/build/run time, shard memory |
   | Triage | First failing phase, suspected class (a–d), artifact links |

   Use the union of original ranges for fallback coverage, avoiding double-counting nested fragments. Count copied preludes or wrapper text separately if those are introduced later. Report aggregate coverage over the discovered corpus, with explicit skipped, blocked, and unexercised-module counts.

Open risks remain: source-context support changes the current root-anchored EDSL contract; documentation requires substantial custom-world functionality; provenance-sensitive output may exceed the intended equivalence contract; function normalization is necessarily incomplete; generated-code memory must be measured; and origin/snippet limits can be reached by large documents. The current registry caps snippets at 4,096 and origin/snippet ranges at roughly 8 MiB, so resource-limit failures need their own records rather than generic “conversion failed.”

This was a read-only source review. Concurrent generator edits appeared during it; the findings above concern the established evaluator/EDSL behavior and the proposed architecture.

**VERDICT: REQUEST CHANGES** — replace the prelude/continuation scheme with scope-contained fallback rules, specify source-context handling, and replace the permissive converted-mode oracle before implementing the broad translator.
