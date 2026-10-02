// Port of `fancy-regex` 0.16.2 `src/compile.rs`: compilation of regexes to
// VM.

///|
// I'm thinking it probably doesn't make a lot of sense having this split
// out from Compiler.
priv struct VMBuilder {
  prog : Array[Insn]
  mut n_saves : Int
}

///|
fn VMBuilder::new(max_group : Int) -> VMBuilder {
  { prog: [], n_saves: max_group * 2 }
}

///|
fn VMBuilder::build(self : VMBuilder) -> Prog {
  Prog::new(self.prog, self.n_saves)
}

///|
fn VMBuilder::newsave(self : VMBuilder) -> Int {
  let result = self.n_saves
  self.n_saves += 1
  result
}

///|
fn VMBuilder::pc(self : VMBuilder) -> Int {
  self.prog.length()
}

///|
// would "emit" be a better name?
fn VMBuilder::add(self : VMBuilder, insn : Insn) -> Unit {
  self.prog.push(insn)
}

///|
fn VMBuilder::set_jmp_target(
  self : VMBuilder,
  jmp_pc : Int,
  target : Int,
) -> Unit {
  match self.prog[jmp_pc] {
    Jmp(_) => self.prog[jmp_pc] = Jmp(target)
    _ => abort("mutating instruction other than Jmp")
  }
}

///|
fn VMBuilder::set_split_target(
  self : VMBuilder,
  split_pc : Int,
  target : Int,
  second : Bool,
) -> Unit {
  match self.prog[split_pc] {
    Split(x, _) if second => self.prog[split_pc] = Split(x, target)
    Split(_, y) => self.prog[split_pc] = Split(target, y)
    _ => abort("mutating instruction other than Split")
  }
}

///|
fn VMBuilder::set_repeat_target(
  self : VMBuilder,
  repeat_pc : Int,
  target : Int,
) -> Unit {
  self.prog[repeat_pc] = match self.prog[repeat_pc] {
    RepeatGr(lo~, hi~, repeat~, ..) => RepeatGr(lo~, hi~, next=target, repeat~)
    RepeatNg(lo~, hi~, repeat~, ..) => RepeatNg(lo~, hi~, next=target, repeat~)
    RepeatEpsilonGr(lo~, repeat~, check~, ..) =>
      RepeatEpsilonGr(lo~, next=target, repeat~, check~)
    RepeatEpsilonNg(lo~, repeat~, check~, ..) =>
      RepeatEpsilonNg(lo~, next=target, repeat~, check~)
    _ => abort("mutating instruction other than Repeat")
  }
}

///|
priv struct Compiler {
  b : VMBuilder
  options : RegexOptions
}

///|
fn Compiler::new(max_group : Int) -> Compiler {
  { b: VMBuilder::new(max_group), options: RegexOptions::default() }
}

///|
fn Compiler::visit(self : Compiler, info : Info, hard : Bool) -> Unit raise FancyError {
  if !hard && !info.hard {
    // easy case, delegate entire subexpr
    return self.compile_delegate(info)
  }
  match info.expr {
    Empty => ()
    Literal(val~, casei~) =>
      if !casei {
        self.b.add(Lit(val))
      } else {
        self.compile_delegate(info)
      }
    Any(newline=true) => self.b.add(Any)
    Any(newline=false) => self.b.add(AnyNoNL)
    Concat(_) => self.compile_concat(info, hard)
    Alt(_) => {
      let count = info.children.length()
      self.compile_alt(count, (compiler, i) => compiler.visit(
        info.children[i],
        hard,
      ))
    }
    Group(_) => {
      let group = info.start_group
      self.b.add(Save(group * 2))
      self.visit(info.children[0], hard)
      self.b.add(Save(group * 2 + 1))
    }
    Repeat(lo~, hi~, greedy~, ..) =>
      self.compile_repeat(info, lo, hi, greedy, hard)
    LookAround(_, la) => self.compile_lookaround(info, la)
    Backref(group~, casei~) => self.b.add(Backref(slot=group * 2, casei~))
    BackrefExistsCondition(group) => self.b.add(BackrefExistsCondition(group))
    AtomicGroup(_) => {
      // TODO optimization: atomic insns are not needed if the
      // child doesn't do any backtracking.
      self.b.add(BeginAtomic)
      self.visit(info.children[0], false)
      self.b.add(EndAtomic)
    }
    Delegate(_) =>
      // TODO: might want to have more specialized impls
      self.compile_delegate(info)
    Assertion(assertion) => self.b.add(Assertion(assertion))
    KeepOut => self.b.add(Save(0))
    ContinueFromPreviousMatchEnd => self.b.add(ContinueFromPreviousMatchEnd)
    Conditional(_) =>
      self.compile_conditional((compiler, i) => compiler.visit(
        info.children[i],
        hard,
      ))
    SubroutineCall(_) =>
      raise FancyError::CompileError(FeatureNotYetSupported("Subroutine Call"))
    UnresolvedNamedSubroutineCall(_) => abort("unreachable")
    BackrefWithRelativeRecursionLevel(_) => abort("unreachable")
  }
}

///|
fn Compiler::compile_alt(
  self : Compiler,
  count : Int,
  handle_alternative : (Compiler, Int) -> Unit raise FancyError,
) -> Unit raise FancyError {
  let jmps = []
  let mut last_pc = USIZE_MAX
  for i in 0..<count {
    let has_next = i != count - 1
    let pc = self.b.pc()
    if has_next {
      self.b.add(Split(pc + 1, USIZE_MAX))
    }
    if last_pc != USIZE_MAX {
      self.b.set_split_target(last_pc, pc, true)
    }
    last_pc = pc
    handle_alternative(self, i)
    if has_next {
      // All except the last branch need to jump over instructions of
      // other branches. The last branch can just continue to the next
      // instruction.
      let pc = self.b.pc()
      jmps.push(pc)
      self.b.add(Jmp(0))
    }
  }
  let next_pc = self.b.pc()
  for jmp_pc in jmps {
    self.b.set_jmp_target(jmp_pc, next_pc)
  }
}

///|
fn Compiler::compile_conditional(
  self : Compiler,
  handle_child : (Compiler, Int) -> Unit raise FancyError,
) -> Unit raise FancyError {
  // here we use atomic group functionality to be able to remove the program counter
  // relating to the split instruction's second position if the conditional succeeds
  // This is to ensure that if the condition succeeds, but the "true" branch from the
  // conditional fails, that it wouldn't jump to the "false" branch.
  self.b.add(BeginAtomic)
  let split_pc = self.b.pc()
  // add the split instruction - we will update it's second pc later
  self.b.add(Split(split_pc + 1, USIZE_MAX))

  // add the conditional expression
  handle_child(self, 0)

  // mark it as successful to remove the state we added as a split earlier
  self.b.add(EndAtomic)

  // add the truth branch
  handle_child(self, 1)
  // add an instruction to jump over the false branch - we will update the jump target later
  let jump_over_false_pc = self.b.pc()
  self.b.add(Jmp(0))

  // add the false branch, update the split target
  self.b.set_split_target(split_pc, self.b.pc(), true)
  handle_child(self, 2)

  // update the jump target for jumping over the false branch
  self.b.set_jmp_target(jump_over_false_pc, self.b.pc())
}

///|
fn Compiler::compile_concat(
  self : Compiler,
  info : Info,
  hard : Bool,
) -> Unit raise FancyError {
  let children = info.children
  // First: determine a prefix which is constant size and not hard.
  let mut prefix_end = 0
  while prefix_end < children.length() &&
        children[prefix_end].const_size &&
        !children[prefix_end].hard {
    prefix_end += 1
  }

  // If incoming difficulty is not hard, the suffix after the last
  // hard child can be done with NFA.
  let mut suffix_len = 0
  for i = children.length() - 1; i >= prefix_end; i = i - 1 {
    let c = children[i]
    // Even for hard, we can delegate a const-sized suffix
    if c.hard || (hard && !c.const_size) {
      break
    }
    suffix_len += 1
  }
  let suffix_begin = children.length() - suffix_len
  self.compile_delegates(children[:prefix_end])
  for child in children[prefix_end:suffix_begin] {
    self.visit(child, true)
  }
  self.compile_delegates(children[suffix_begin:])
}

///|
fn Compiler::compile_repeat(
  self : Compiler,
  info : Info,
  lo : Int,
  hi : Int,
  greedy : Bool,
  hard : Bool,
) -> Unit raise FancyError {
  let child = info.children[0]
  if lo == 0 && hi == 1 {
    // e?
    let pc = self.b.pc()
    self.b.add(Split(pc + 1, pc + 1))
    // TODO: do we want to do an epsilon check here? If we do
    // it here and in Alt, we might be able to make a good
    // bound on stack depth
    self.visit(child, hard)
    let next_pc = self.b.pc()
    self.b.set_split_target(pc, next_pc, greedy)
    return
  }
  let hard = hard || info.hard
  if hi == USIZE_MAX && child.min_size == 0 {
    // Use RepeatEpsilon instructions to prevent empty repeat
    let repeat = self.b.newsave()
    let check = self.b.newsave()
    self.b.add(Save0(repeat))
    let pc = self.b.pc()
    if greedy {
      self.b.add(RepeatEpsilonGr(lo~, next=USIZE_MAX, repeat~, check~))
    } else {
      self.b.add(RepeatEpsilonNg(lo~, next=USIZE_MAX, repeat~, check~))
    }
    self.visit(child, hard)
    self.b.add(Jmp(pc))
    let next_pc = self.b.pc()
    self.b.set_repeat_target(pc, next_pc)
  } else if lo == 0 && hi == USIZE_MAX {
    // e*
    let pc = self.b.pc()
    self.b.add(Split(pc + 1, pc + 1))
    self.visit(child, hard)
    self.b.add(Jmp(pc))
    let next_pc = self.b.pc()
    self.b.set_split_target(pc, next_pc, greedy)
  } else if lo == 1 && hi == USIZE_MAX {
    // e+
    let pc = self.b.pc()
    self.visit(child, hard)
    let next = self.b.pc() + 1
    let (x, y) = if greedy { (pc, next) } else { (next, pc) }
    self.b.add(Split(x, y))
  } else {
    let repeat = self.b.newsave()
    self.b.add(Save0(repeat))
    let pc = self.b.pc()
    if greedy {
      self.b.add(RepeatGr(lo~, hi~, next=USIZE_MAX, repeat~))
    } else {
      self.b.add(RepeatNg(lo~, hi~, next=USIZE_MAX, repeat~))
    }
    self.visit(child, hard)
    self.b.add(Jmp(pc))
    let next_pc = self.b.pc()
    self.b.set_repeat_target(pc, next_pc)
  }
}

///|
fn Compiler::compile_lookaround(
  self : Compiler,
  info : Info,
  la : LookAround,
) -> Unit raise FancyError {
  let inner = info.children[0]
  match la {
    LookBehind =>
      if !inner.const_size && inner.expr is Alt(_) {
        // Make const size by transforming `(?<=a|bb)` to `(?<=a)|(?<=bb)`
        let alternatives = inner.children
        self.compile_alt(alternatives.length(), (compiler, i) => {
          let alternative = alternatives[i]
          compiler.compile_positive_lookaround(alternative, la)
        })
      } else {
        self.compile_positive_lookaround(inner, la)
      }
    LookBehindNeg =>
      if !inner.const_size && inner.expr is Alt(_) {
        // Make const size by transforming `(?<!a|bb)` to `(?<!a)(?<!bb)`
        let alternatives = inner.children
        for alternative in alternatives {
          self.compile_negative_lookaround(alternative, la)
        }
      } else {
        self.compile_negative_lookaround(inner, la)
      }
    LookAhead => self.compile_positive_lookaround(inner, la)
    LookAheadNeg => self.compile_negative_lookaround(inner, la)
  }
}

///|
fn Compiler::compile_positive_lookaround(
  self : Compiler,
  inner : Info,
  la : LookAround,
) -> Unit raise FancyError {
  let save = self.b.newsave()
  self.b.add(Save(save))
  self.compile_lookaround_inner(inner, la)
  self.b.add(Restore(save))
}

///|
fn Compiler::compile_negative_lookaround(
  self : Compiler,
  inner : Info,
  la : LookAround,
) -> Unit raise FancyError {
  let pc = self.b.pc()
  self.b.add(Split(pc + 1, USIZE_MAX))
  self.compile_lookaround_inner(inner, la)
  self.b.add(FailNegativeLookAround)
  let next_pc = self.b.pc()
  self.b.set_split_target(pc, next_pc, true)
}

///|
fn Compiler::compile_lookaround_inner(
  self : Compiler,
  inner : Info,
  la : LookAround,
) -> Unit raise FancyError {
  if la == LookBehind || la == LookBehindNeg {
    if !inner.const_size {
      raise FancyError::CompileError(LookBehindNotConst)
    }
    self.b.add(GoBack(inner.min_size))
  }
  self.visit(inner, false)
}

///|
fn Compiler::compile_delegates(
  self : Compiler,
  infos : ArrayView[Info],
) -> Unit raise FancyError {
  if infos.is_empty() {
    return
  }
  // TODO: might want to do something similar for case insensitive literals
  // (have is_literal return an additional bool for casei)
  if infos.iter().all(e => e.is_literal()) {
    let val = StringBuilder()
    for info in infos {
      info.push_literal(val)
    }
    self.b.add(Lit(val.to_string()))
    return
  }
  let delegate_builder = DelegateBuilder::new()
  for info in infos {
    delegate_builder.push(info) |> ignore
  }
  let delegate = delegate_builder.build(self.options)
  self.b.add(delegate)
}

///|
fn Compiler::compile_delegate(self : Compiler, info : Info) -> Unit raise FancyError {
  let insn = if info.is_literal() {
    let val = StringBuilder()
    info.push_literal(val)
    Lit(val.to_string())
  } else {
    DelegateBuilder::new().push(info).build(self.options)
  }
  self.b.add(insn)
}

///|
/// Compile a delegated regex with the `regex` package (upstream
/// `compile_inner`, which builds a `regex_automata` meta regex).
fn compile_inner(
  inner_re : String,
  options : RegexOptions,
) -> @regex.Regex raise FancyError {
  let syntaxc = options.syntaxc
  @regex.Regex::new_with(
    inner_re,
    case_insensitive=syntaxc.case_insensitive,
    multi_line=syntaxc.multi_line,
    dot_matches_new_line=syntaxc.dot_matches_new_line,
    ignore_whitespace=syntaxc.ignore_whitespace,
    unicode=syntaxc.unicode,
  ) catch {
    @regex.RegexError(msg) => raise FancyError::CompileError(InnerError(msg))
    _ => raise FancyError::CompileError(InnerError(""))
  }
}

///|
/// Compile the analyzed expressions into a program.
pub fn compile(info : Info, anchored : Bool) -> Prog raise FancyError {
  let c = Compiler::new(info.end_group)
  if !anchored {
    // add instructions as if \O*? was used at the start of the expression
    // so that we bump the haystack index by one when failing to match at the current position
    let current_pc = c.b.pc()
    // we are adding 3 instructions, so the current program counter plus 3 gives us the first real instruction
    c.b.add(Split(current_pc + 3, current_pc + 1))
    c.b.add(Any)
    c.b.add(Jmp(current_pc))
  }
  if info.start_group == 1 {
    // add implicit capture group 0 begin
    c.b.add(Save(0))
  }
  c.visit(info, false)
  if info.start_group == 1 {
    // add implicit capture group 0 end
    c.b.add(Save(1))
  }
  c.b.add(End)
  c.b.build()
}

///|
priv struct DelegateBuilder {
  re : StringBuilder
  mut min_size : Int
  mut const_size : Bool
  mut start_group : Int?
  mut end_group : Int
}

///|
fn DelegateBuilder::new() -> DelegateBuilder {
  {
    re: StringBuilder(),
    min_size: 0,
    const_size: true,
    start_group: None,
    end_group: 0,
  }
}

///|
fn DelegateBuilder::push(self : DelegateBuilder, info : Info) -> DelegateBuilder {
  // TODO: might want to detect case of a group with no captures
  //  inside, so we can run find() instead of captures()
  self.min_size = sat_add(self.min_size, info.min_size)
  self.const_size = self.const_size && info.const_size
  if self.start_group is None {
    self.start_group = Some(info.start_group)
  }
  self.end_group = info.end_group

  // Add expression. The precedence argument has to be 1 here to
  // ensure correct grouping in these cases:
  //
  // If we have multiple expressions, we are building a concat.
  // Without grouping, we'd turn ["a", "b|c"] into "^ab|c". But we
  // want "^a(?:b|c)".
  //
  // Even with a single expression, because we add `^` at the
  // beginning, we need a group. Otherwise `["a|b"]` would be turned
  // into `"^a|b"` instead of `"^(?:a|b)"`.
  info.expr.to_str(self.re, 1)
  self
}

///|
fn DelegateBuilder::build(
  self : DelegateBuilder,
  options : RegexOptions,
) -> Insn raise FancyError {
  guard self.start_group is Some(start_group) else {
    abort("Expected at least one expression")
  }
  let end_group = self.end_group
  let pattern = self.re.to_string()
  let compiled = compile_inner(pattern, options)
  Delegate({
    inner: compiled,
    pattern,
    start_group,
    end_group,
    slots: FixedArray::make((end_group - start_group + 1) * 2, -1),
  })
}
