// Port of `fancy-regex` 0.16.2 `src/analyze.rs`: analysis of regex
// expressions.

///|
/// The analysis of an expression.
pub struct Info {
  start_group : Int
  end_group : Int
  min_size : Int
  const_size : Bool
  hard : Bool
  expr : Expr
  children : Array[Info]
}

///|
fn Info::is_literal(self : Info) -> Bool {
  match self.expr {
    Literal(casei~, ..) => !casei
    Concat(_) => self.children.iter().all(child => child.is_literal())
    _ => false
  }
}

///|
fn Info::push_literal(self : Info, buf : StringBuilder) -> Unit {
  match self.expr {
    // could be more paranoid about checking casei
    Literal(val~, ..) => buf.write_string(val)
    Concat(_) =>
      for child in self.children {
        child.push_literal(buf)
      }
    _ => abort("push_literal called on non-literal")
  }
}

///|
priv struct SizeInfo {
  min_size : Int
  const_size : Bool
}

///|
priv struct Analyzer {
  backrefs : BitSet
  mut group_ix : Int
  /// Stores the analysis info for each group by group number
  group_info : Map[Int, SizeInfo]
}

///|
/// Saturating `usize` addition.
fn sat_add(a : Int, b : Int) -> Int {
  let s = a.to_int64() + b.to_int64()
  if s > USIZE_MAX.to_int64() {
    USIZE_MAX
  } else {
    s.to_int()
  }
}

///|
/// Saturating `usize` multiplication.
fn sat_mul(a : Int, b : Int) -> Int {
  let s = a.to_int64() * b.to_int64()
  if s > USIZE_MAX.to_int64() {
    USIZE_MAX
  } else {
    s.to_int()
  }
}

///|
fn Analyzer::visit(self : Analyzer, expr : Expr) -> Info raise FancyError {
  let start_group = self.group_ix
  let children = []
  let mut min_size = 0
  let mut const_size = false
  let mut hard = false
  match expr {
    Assertion(assertion) if assertion.is_hard() => {
      const_size = true
      hard = true
    }
    Empty | Assertion(_) => const_size = true
    Any(_) => {
      min_size = 1
      const_size = true
    }
    Literal(val~, casei~) => {
      // right now each character in a literal gets its own node, that might change
      min_size = 1
      const_size = literal_const_size(val, casei)
    }
    Concat(v) => {
      const_size = true
      for child in v {
        let child_info = self.visit(child)
        min_size = sat_add(min_size, child_info.min_size)
        const_size = const_size && child_info.const_size
        hard = hard || child_info.hard
        children.push(child_info)
      }
    }
    Alt(v) => {
      let child_info = self.visit(v[0])
      min_size = child_info.min_size
      const_size = child_info.const_size
      hard = child_info.hard
      children.push(child_info)
      for child in v[1:] {
        let child_info = self.visit(child)
        const_size = const_size &&
          child_info.const_size &&
          min_size == child_info.min_size
        min_size = if child_info.min_size < min_size {
          child_info.min_size
        } else {
          min_size
        }
        hard = hard || child_info.hard
        children.push(child_info)
      }
    }
    Group(child) => {
      let group = self.group_ix
      self.group_ix += 1
      let child_info = self.visit(child)
      min_size = child_info.min_size
      const_size = child_info.const_size
      // Store the group info for use by backrefs
      self.group_info[group] = { min_size, const_size, }
      // If there's a backref to this group, we potentially have to backtrack within the
      // group. E.g. with `(x|xy)\1` and input `xyxy`, `x` matches but then the backref
      // doesn't, so we have to backtrack and try `xy`.
      hard = child_info.hard || self.backrefs.contains(group)
      children.push(child_info)
    }
    LookAround(child, _) => {
      let child_info = self.visit(child)
      // min_size = 0
      const_size = true
      hard = true
      children.push(child_info)
    }
    Repeat(child~, lo~, hi~, ..) => {
      let child_info = self.visit(child)
      min_size = sat_mul(child_info.min_size, lo)
      const_size = child_info.const_size && lo == hi
      hard = child_info.hard
      children.push(child_info)
    }
    Delegate(size~, ..) => {
      // currently only used for empty and single-char matches
      min_size = size
      const_size = true
    }
    Backref(group~, ..) => {
      if group == 0 {
        raise FancyError::CompileError(InvalidBackref(group))
      }
      // Look up the referenced group's size information
      if self.group_info.get(group) is Some(info) {
        min_size = info.min_size
        const_size = info.const_size
      }
      hard = true
    }
    AtomicGroup(child) => {
      let child_info = self.visit(child)
      min_size = child_info.min_size
      const_size = child_info.const_size
      hard = true // TODO: possibly could weaken
      children.push(child_info)
    }
    KeepOut => {
      hard = true
      const_size = true
    }
    ContinueFromPreviousMatchEnd => {
      hard = true
      const_size = true
    }
    BackrefExistsCondition(_) => {
      hard = true
      const_size = true
    }
    Conditional(condition~, true_branch~, false_branch~) => {
      hard = true
      let child_info_condition = self.visit(condition)
      let child_info_truth = self.visit(true_branch)
      let child_info_false = self.visit(false_branch)
      min_size = sat_add(
        child_info_condition.min_size,
        if child_info_truth.min_size < child_info_false.min_size {
          child_info_truth.min_size
        } else {
          child_info_false.min_size
        },
      )
      const_size = child_info_condition.const_size &&
        child_info_truth.const_size &&
        child_info_false.const_size &&
        // if the condition's size plus the truth branch's size is equal to the false branch's size then it's const size
        sat_add(child_info_condition.min_size, child_info_truth.min_size) ==
        child_info_false.min_size
      children.push(child_info_condition)
      children.push(child_info_truth)
      children.push(child_info_false)
    }
    SubroutineCall(_) =>
      raise FancyError::CompileError(FeatureNotYetSupported("Subroutine Call"))
    UnresolvedNamedSubroutineCall(name~, ix~) =>
      raise FancyError::CompileError(SubroutineCallTargetNotFound(name, ix))
    BackrefWithRelativeRecursionLevel(_) =>
      raise FancyError::CompileError(
        FeatureNotYetSupported("Backref at recursion level"),
      )
  }
  {
    expr,
    children,
    start_group,
    end_group: self.group_ix,
    min_size,
    const_size,
    hard,
  }
}

///|
fn literal_const_size(_val : String, _casei : Bool) -> Bool {
  // Right now, regex doesn't do sophisticated case folding,
  // test below will fail when that changes, then we need to
  // do something fancier here.
  true
}

///|
/// Analyze the parsed expression to determine whether it requires fancy
/// features.
pub fn analyze(
  tree : ExprTree,
  explicit_capture_group_0 : Bool,
) -> Info raise FancyError {
  let start_group = if explicit_capture_group_0 { 0 } else { 1 }
  let analyzer : Analyzer = {
    backrefs: tree.backrefs,
    group_ix: start_group,
    group_info: {},
  }
  let analyzed : Result[Info, FancyError] = try
    analyzer.visit(tree.expr)
  catch {
    e => Err(e)
  } noraise {
    info => Ok(info)
  }
  if analyzer.backrefs.contains(0) {
    raise FancyError::CompileError(InvalidBackref(0))
  }
  if analyzer.backrefs.last() is Some(highest_backref) {
    if highest_backref > analyzer.group_ix - start_group ||
      // if we have an explicit capture group 0, and the highest backref is the number of capture groups
      // then that backref refers to an invalid group
      // i.e. `(a\1)b`   has no capture group 1
      //      `(a(b))\2` has no capture group 2
      (highest_backref == analyzer.group_ix && start_group == 0) {
      raise FancyError::CompileError(InvalidBackref(highest_backref))
    }
  }
  match analyzed {
    Ok(info) => info
    Err(e) => raise e
  }
}

///|
/// Determine if the expression will always only ever match at position 0.
/// Note that false negatives are possible - it can return false even if it
/// could be anchored. This should therefore only be treated as an
/// optimization.
pub fn can_compile_as_anchored(root_expr : Expr) -> Bool {
  match root_expr {
    Concat(children) =>
      match children[0] {
        Assertion(assertion) => assertion == StartText
        _ => false
      }
    Assertion(assertion) => assertion == StartText
    _ => false
  }
}
