// Port of `syntect/src/parsing/scope.rs` (syntect 5.3.0).
//
// Scopes are represented exactly as upstream: up to 8 atoms of 16 bits each,
// packed into two 64-bit integers, with the atom strings interned in a global
// `ScopeRepository`.

///|
/// Scope related errors.
pub(all) suberror ScopeError {
  NoClearedScopesToRestore
}

///|
pub impl Show for ScopeError with fn output(self, logger) {
  match self {
    NoClearedScopesToRestore =>
      logger.write_string(
        "Tried to restore cleared scopes, but none were cleared",
      )
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScopeError with Show::{to_string, output}

///|
/// Multiplier on the power of 2 for MatchPower. This is only exposed for
/// highlighting.
pub let atom_len_bits : Int = 3

///|
/// A hierarchy of atoms with semi-standardized names used to accord semantic
/// information to a specific piece of text.
///
/// For example `source.php` or `keyword.control.flow.loop.c`.
pub(all) struct Scope {
  a : UInt64
  b : UInt64
} derive(Eq, Compare, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Scope with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Scope with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Scope with Hash::{hash, hash_combine}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Scope with Default::{default}

///|
/// Not all strings are valid scopes.
pub(all) suberror ParseScopeError {
  /// Due to a limitation of the current optimized internal representation
  /// scopes can be at most 8 atoms long.
  TooLong
  /// The internal representation uses 16 bits per atom, so if all scopes ever
  /// used by the program have more than 2^16-2 atoms, things break.
  TooManyAtoms
}

///|
pub impl Show for ParseScopeError with fn output(self, logger) {
  match self {
    TooLong =>
      logger.write_string("Too long scope. Scopes can be at most 8 atoms long.")
    TooManyAtoms =>
      logger.write_string("Too many atoms. Max 2^16-2 atoms allowed.")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ParseScopeError with Show::{to_string, output}

///|
/// The structure used to keep track of the mapping between scope atom
/// numbers and their string names.
pub struct ScopeRepository {
  priv atoms : Array[String]
  priv atom_index_map : Map[String, Int]
}

///|
/// The global scope repository (upstream `SCOPE_REPO`).
let scope_repo : ScopeRepository = ScopeRepository::new()

///|
/// A stack/sequence of scopes for representing hierarchies for a given token
/// of text.
pub(all) struct ScopeStack {
  clear_stack : Array[Array[Scope]]
  scopes : Array[Scope]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScopeStack with Eq::{not_equal, equal}

///|
/// How many scopes to clear.
pub(all) enum ClearAmount {
  TopN(Int)
  All
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ClearAmount with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ClearAmount with @debug.Debug::{to_repr}

///|
/// A change to a scope stack.
pub(all) enum ScopeStackOp {
  Push(Scope)
  Pop(Int)
  /// Used for the `clear_scopes` feature
  Clear(ClearAmount)
  /// Restores cleared scopes
  Restore
  Noop
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScopeStackOp with Eq::{not_equal, equal}

///|
/// Used for `ScopeStack::apply_with_hook`.
pub(all) enum BasicScopeStackOp {
  Push(Scope)
  Pop
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BasicScopeStackOp with Eq::{not_equal, equal}

///|
fn pack_as_u16s(atoms : Array[Int]) -> Scope raise ParseScopeError {
  let mut a = 0UL
  let mut b = 0UL
  for i, n in atoms {
    if n >= 65535 - 2 {
      raise TooManyAtoms
    }
    let small = (n + 1).to_uint64() // +1 since we reserve 0 for unused
    if i < 4 {
      let shift = (3 - i) * 16
      a = a | (small << shift)
    } else {
      let shift = (7 - i) * 16
      b = b | (small << shift)
    }
  }
  { a, b, }
}

///|
fn ScopeRepository::new() -> ScopeRepository {
  { atoms: [], atom_index_map: {}, }
}

///|
/// Builds a scope from its string representation in this repository.
pub fn ScopeRepository::build(
  self : ScopeRepository,
  s : StringView,
) -> Scope raise ParseScopeError {
  if s.is_empty() {
    return { a: 0, b: 0, }
  }
  let parts = s
    .trim_end(chars=".")
    .split(".")
    .map(a => self.atom_to_index(a.to_owned()))
    .collect()
  if parts.length() > 8 {
    raise TooManyAtoms
  }
  pack_as_u16s(parts)
}

///|
/// Return the string for a scope.
pub fn ScopeRepository::to_string(
  self : ScopeRepository,
  scope : Scope,
) -> String {
  let s = StringBuilder()
  for i in 0..<8 {
    let atom_number = scope.atom_at(i)
    if atom_number == 0 {
      break
    }
    if i != 0 {
      s.write_char('.')
    }
    s.write_string(self.atom_str(atom_number))
  }
  s.to_string()
}

///|
fn ScopeRepository::atom_to_index(self : ScopeRepository, atom : String) -> Int {
  if self.atom_index_map.get(atom) is Some(index) {
    return index
  }
  self.atoms.push(atom)
  let index = self.atoms.length() - 1
  self.atom_index_map[atom] = index
  index
}

///|
/// Return the string for an atom number returned by `Scope::atom_at`.
pub fn ScopeRepository::atom_str(
  self : ScopeRepository,
  atom_number : Int,
) -> String {
  self.atoms[atom_number - 1]
}

///|
/// Parses a `Scope` from a series of atoms separated by dot (`.`)
/// characters. Example: `Scope::new("meta.rails.controller")`
pub fn Scope::new(s : StringView) -> Scope raise ParseScopeError {
  scope_repo.build(rust_trim(s))
}

///|
/// Gets the atom number at a given index.
pub fn Scope::atom_at(self : Scope, index : Int) -> Int {
  let shifted = if index < 4 {
    self.a >> ((3 - index) * 16)
  } else if index < 8 {
    self.b >> ((7 - index) * 16)
  } else {
    abort("atom index out of bounds \{index}")
  }
  (shifted & 0xFFFFUL).to_int()
}

///|
fn Scope::missing_atoms(self : Scope) -> Int {
  let trail = if self.b == 0 { self.a.ctz() + 64 } else { self.b.ctz() }
  trail / 16
}

///|
/// Returns the number of atoms in the scope.
pub fn Scope::len(self : Scope) -> Int {
  8 - self.missing_atoms()
}

///|
pub fn Scope::is_empty(self : Scope) -> Bool {
  self.len() == 0
}

///|
/// Returns the string representation of this scope.
pub fn Scope::build_string(self : Scope) -> String {
  scope_repo.to_string(self)
}

///|
/// Tests if this scope is a prefix of another scope. Note that the empty
/// scope is always a prefix.
pub fn Scope::is_prefix_of(self : Scope, s : Scope) -> Bool {
  let pref_missing = self.missing_atoms()
  let max = 0xFFFFFFFFFFFFFFFFUL
  let (mask0, mask1) = if pref_missing == 8 {
    (0UL, 0UL)
  } else if pref_missing == 4 {
    (max, 0UL)
  } else if pref_missing > 4 {
    (max << ((pref_missing - 4) * 16), 0UL)
  } else {
    (max, max << (pref_missing * 16))
  }
  // xor to find the difference
  let ax = (self.a ^ s.a) & mask0
  let bx = (self.b ^ s.b) & mask1
  ax == 0 && bx == 0
}

///|
pub impl Show for Scope with fn output(self, logger) {
  logger.write_string(self.build_string())
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Scope with Show::{to_string, output}

///|
/// Upstream's `Debug` (`<source.php>`).
pub fn Scope::debug(self : Scope) -> String {
  "<" + self.build_string() + ">"
}

///|
/// Wrapper to get around the fact Rust `f64` doesn't implement `Ord` and
/// there is no non-NaN float type.
pub(all) struct MatchPower(Double) derive(Eq, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MatchPower with Eq::{not_equal, equal}

///|
pub extend MatchPower with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MatchPower with @debug.Debug::{to_repr}

///|
pub fn ScopeStack::new() -> ScopeStack {
  { clear_stack: [], scopes: [], }
}

///|
/// Note: creating a ScopeStack with this doesn't contain information on what
/// to do when `clear_scopes` contexts end.
pub fn ScopeStack::from_vec(v : Array[Scope]) -> ScopeStack {
  { clear_stack: [], scopes: v, }
}

///|
pub fn ScopeStack::push(self : ScopeStack, s : Scope) -> Unit {
  self.scopes.push(s)
}

///|
pub fn ScopeStack::pop(self : ScopeStack) -> Unit {
  self.scopes.pop() |> ignore
}

///|
/// Modifies this stack according to the operation given.
pub fn ScopeStack::apply(
  self : ScopeStack,
  op : ScopeStackOp,
) -> Unit raise ScopeError {
  self.apply_with_hook(op, (_, _) => ())
}

///|
/// Modifies this stack according to the operation given and calls the hook
/// for each basic operation.
pub fn ScopeStack::apply_with_hook(
  self : ScopeStack,
  op : ScopeStackOp,
  hook : (BasicScopeStackOp, ArrayView[Scope]) -> Unit,
) -> Unit raise ScopeError {
  match op {
    Push(scope) => {
      self.scopes.push(scope)
      hook(Push(scope), self.scopes[:])
    }
    Pop(count) =>
      for _ in 0..<count {
        self.scopes.pop() |> ignore
        hook(Pop, self.scopes[:])
      }
    Clear(amount) => {
      let cleared = match amount {
        TopN(n) => {
          // don't try to clear more scopes than are on the stack
          let len = self.scopes.length()
          let to_leave = len - (if n < len { n } else { len })
          let cleared = self.scopes[to_leave:].to_owned()
          self.scopes.truncate(to_leave)
          cleared
        }
        All => {
          let cleared = self.scopes.copy()
          self.scopes.clear()
          cleared
        }
      }
      let clear_amount = cleared.length()
      self.clear_stack.push(cleared)
      for _ in 0..<clear_amount {
        hook(Pop, self.scopes[:])
      }
    }
    Restore =>
      match self.clear_stack.pop() {
        Some(to_push) =>
          for s in to_push {
            self.scopes.push(s)
            hook(Push(s), self.scopes[:])
          }
        None => raise NoClearedScopesToRestore
      }
    Noop => ()
  }
}

///|
/// Return the bottom n elements of the stack.
pub fn ScopeStack::bottom_n(self : ScopeStack, n : Int) -> ArrayView[Scope] {
  self.scopes[0:n]
}

///|
/// Return a slice of the scopes in this stack.
pub fn ScopeStack::as_slice(self : ScopeStack) -> ArrayView[Scope] {
  self.scopes[:]
}

///|
/// Return the height/length of this stack.
pub fn ScopeStack::len(self : ScopeStack) -> Int {
  self.scopes.length()
}

///|
pub fn ScopeStack::is_empty(self : ScopeStack) -> Bool {
  self.len() == 0
}

///|
/// Checks if this stack as a selector matches the given stack, returning
/// the match score if so.
pub fn ScopeStack::does_match(
  self : ScopeStack,
  stack : ArrayView[Scope],
) -> MatchPower? {
  let mut sel_index = 0
  let mut score = 0.0
  for i, scope in stack {
    let sel_scope = self.scopes[sel_index]
    if sel_scope.is_prefix_of(scope) {
      let len = sel_scope.len()
      // equivalent to score |= len << (ATOM_LEN_BITS*i) on a large unsigned
      score += len.to_double() * @math.pow(2.0, (atom_len_bits * i).to_double())
      sel_index += 1
      if sel_index >= self.scopes.length() {
        return Some(MatchPower(score))
      }
    }
  }
  None
}

///|
/// Parses a scope stack from a whitespace separated list of scopes.
pub fn ScopeStack::from_str(s : StringView) -> ScopeStack raise ParseScopeError {
  let scopes = []
  for name in split_whitespace(s) {
    scopes.push(Scope::new(name))
  }
  ScopeStack::from_vec(scopes)
}

///|
pub impl Show for ScopeStack with fn output(self, logger) {
  for s in self.scopes {
    logger.write_string(s.build_string())
    logger.write_char(' ')
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScopeStack with Show::{to_string, output}

///|
/// Rust's `str::split_whitespace`.
pub fn split_whitespace(s : StringView) -> Array[StringView] {
  let out = []
  let mut start = -1
  let mut i = 0
  while i < s.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    let ws = @unicode.is_whitespace(c.unsafe_to_char())
    if ws {
      if start >= 0 {
        out.push(s[start:i])
        start = -1
      }
    } else if start < 0 {
      start = i
    }
    i = next
  }
  if start >= 0 {
    out.push(s[start:])
  }
  out
}
