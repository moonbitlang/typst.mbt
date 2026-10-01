// Port of the parts of the `codex` crate (typst/codex, `src/lib.rs` and
// `src/shared.rs`) that upstream Typst uses. The symbol data itself is
// generated into `symbols_gen.mbt` by `oracle/src/bin/gen_symbols.rs`.

///|
/// A set of modifiers.
///
/// Beware: The `Eq` and `Hash` implementations are dependent on the
/// ordering of the modifiers, in opposition to what a set would usually
/// constitute.
pub(all) struct ModifierSet(String) derive(Eq, Hash, Debug)

///|
/// Constructs a modifier set from a string, where modifiers are separated by
/// the character `.`.
///
/// `s` should not contain any empty modifiers (i.e. it shouldn't contain the
/// sequence `..`) and no modifier should occur twice.
pub fn ModifierSet::from_raw_dotted(s : String) -> ModifierSet {
  ModifierSet(s)
}

///|
/// Constructs the default (empty) modifier set.
pub fn ModifierSet::default() -> ModifierSet {
  ModifierSet("")
}

///|
/// Whether `self` is empty.
pub fn ModifierSet::is_empty(self : ModifierSet) -> Bool {
  self.0.is_empty()
}

///|
/// Gets the string of modifiers separated by `.`.
pub fn ModifierSet::as_str(self : ModifierSet) -> String {
  self.0
}

///|
/// Inserts a new modifier into the set.
///
/// `m` should not be empty, contain the character `.`, or already be in the
/// set.
pub fn ModifierSet::insert_raw(self : ModifierSet, m : String) -> ModifierSet {
  if self.0.is_empty() {
    ModifierSet(m)
  } else {
    ModifierSet(self.0 + "." + m)
  }
}

///|
/// Iterates over the list of modifiers in an arbitrary order.
pub fn ModifierSet::iter(self : ModifierSet) -> Array[String] {
  if self.0.is_empty() {
    return []
  }
  self.0.split(".").map(v => v.to_owned()).to_array()
}

///|
/// Whether the set contains the modifier `m`.
pub fn ModifierSet::contains(self : ModifierSet, m : String) -> Bool {
  self.iter().iter().any(lhs => lhs == m)
}

///|
/// Finds the best match from the list.
///
/// To be considered a match, the modifier set must be a superset of (or
/// equal to) `self`. Among different matches, the best one is selected by
/// the following two criteria (in order):
/// 1. Number of modifiers in common with `self` (more is better).
/// 2. Total number of modifiers (fewer is better).
///
/// If there are multiple best matches, the first of them is returned.
pub fn[T] ModifierSet::best_match_in(
  self : ModifierSet,
  variants : Iter[(ModifierSet, T)],
) -> T? {
  let mut best : T? = None
  let mut best_score : (Int, Int)? = None

  // Find the best table entry with this name.
  for candidate in variants {
    if !self.is_subset(candidate.0) {
      continue
    }
    let mut matching = 0
    let mut total = 0
    for modifier in candidate.0.iter() {
      if self.contains(modifier) {
        matching += 1
      }
      total += 1
    }
    let score = (matching, total)
    let better = match best_score {
      None => true
      // `(matching, Reverse(total)) > best`
      Some((bm, bt)) => matching > bm || (matching == bm && total < bt)
    }
    if better {
      best = Some(candidate.1)
      best_score = Some(score)
    }
  }
  best
}

///|
/// Whether all modifiers in `self` are also present in `other`.
pub fn ModifierSet::is_subset(self : ModifierSet, other : ModifierSet) -> Bool {
  self.iter().iter().all(m => other.contains(m))
}

///|
/// A symbol variant, consisting of a set of modifiers, the variant's value,
/// and an optional deprecation message.
pub type SymbolVariantData = (ModifierSet, String, String?)

///|
/// A module of definitions (upstream `codex::Module`).
priv struct CodexModule(Array[(String, CodexBinding)])

///|
/// A definition bound in a module, with metadata (upstream
/// `codex::Binding`).
priv struct CodexBinding {
  /// The bound definition.
  def : CodexDef
  /// A deprecation message for the definition, if it is deprecated.
  deprecation : String?
}

///|
/// A definition in a module (upstream `codex::Def`).
priv enum CodexDef {
  /// A symbol, potentially with modifiers.
  Symbol(CodexSymbol)
  /// A nested module.
  Module(CodexModule)
}

///|
/// A symbol, either a leaf or with modifiers and optional deprecation
/// (upstream `codex::Symbol`).
priv enum CodexSymbol {
  /// A symbol without modifiers.
  Single(String)
  /// A symbol with named modifiers. The symbol defaults to its first
  /// variant.
  Multi(Array[SymbolVariantData])
}

///|
/// Iterate over the module's definitions.
fn CodexModule::iter(self : CodexModule) -> Array[(String, CodexBinding)] {
  self.0
}

///|
let codex_sym_cell : Ref[CodexModule?] = { val: None, }

///|
/// Named general symbols (upstream `codex::SYM`).
fn codex_sym() -> CodexModule {
  match codex_sym_cell.val {
    Some(m) => m
    None => {
      let m = codex_sym_data()
      codex_sym_cell.val = Some(m)
      m
    }
  }
}

///|
let codex_emoji_cell : Ref[CodexModule?] = { val: None, }

///|
/// Named emoji (upstream `codex::EMOJI`).
fn codex_emoji() -> CodexModule {
  match codex_emoji_cell.val {
    Some(m) => m
    None => {
      let m = codex_emoji_data()
      codex_emoji_cell.val = Some(m)
      m
    }
  }
}

///|
/// A module that contains the other top-level modules (upstream
/// `codex::ROOT`).
fn codex_root() -> CodexModule {
  CodexModule([
    ("emoji", { def: Module(codex_emoji()), deprecation: None, }),
    ("sym", { def: Module(codex_sym()), deprecation: None, }),
  ])
}
