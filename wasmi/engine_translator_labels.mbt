// Port of wasmi 1.0.9 `engine/translator/labels.rs` and the `Instr` type of
// `engine/translator/utils.rs`.

///|
/// A reference to an encoded [`Op`] (its index in the instruction sequence).
pub(all) struct Instr(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Instr with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Instr with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Instr with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Instr with @debug.Debug::{to_repr}

///|
/// Creates an [`Instr`] from the given `usize` value.
pub fn Instr::from_usize(value : Int) -> Instr {
  Instr(value)
}

///|
/// Returns an `usize` representation of the instruction index.
pub fn Instr::into_usize(self : Instr) -> Int {
  self.0
}

///|
/// Returns the `u32` representation of the instruction index.
pub fn Instr::to_u32(self : Instr) -> UInt {
  self.0.reinterpret_as_uint()
}

///|
/// Returns the absolute distance between `self` and `other`.
pub fn Instr::distance(self : Instr, other : Instr) -> Int {
  (self.0 - other.0).abs()
}

///|
/// A label during the Wasmi compilation process.
priv enum Label {
  /// The label has already been pinned to a particular [`Instr`].
  Pinned(Instr)
  /// The label is still unpinned.
  Unpinned
}

///|
/// A reference to an [`Label`].
pub(all) struct LabelRef(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LabelRef with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LabelRef with @debug.Debug::{to_repr}

///|
/// The label registry.
///
/// Allows to allocate new labels pin them and resolve pinned ones.
pub(all) struct LabelRegistry {
  priv labels : Array[Label]
  priv users : Array[LabelUser]
}

///|
/// A user of a label.
priv struct LabelUser {
  /// The label in use by the user.
  label : LabelRef
  /// The reference to the using instruction.
  user : Instr
}

///|
pub fn LabelRegistry::new() -> LabelRegistry {
  { labels: [], users: [], }
}

///|
/// Resets the [`LabelRegistry`] for reuse.
pub fn LabelRegistry::reset(self : LabelRegistry) -> Unit {
  self.labels.clear()
  self.users.clear()
}

///|
/// Allocates a new unpinned label and returns its reference.
pub fn LabelRegistry::new_label(self : LabelRegistry) -> LabelRef {
  let index = self.labels.length()
  self.labels.push(Unpinned)
  LabelRef(index)
}

///|
/// Pins the `label` to the given `instr`.
///
/// # Errors
///
/// If the `label` has already been pinned to some other [`Instr`].
pub fn LabelRegistry::pin_label(
  self : LabelRegistry,
  label : LabelRef,
  instr : Instr,
) -> Unit raise Failure {
  match self.labels[label.0] {
    Pinned(pinned) =>
      fail(
        "trying to pin already pinned label LabelRef(\{label.0}) (pinned to Instr(\{pinned.0}))",
      )
    Unpinned => self.labels[label.0] = Pinned(instr)
  }
}

///|
/// Pins the `label` to the given `instr` if unpinned.
pub fn LabelRegistry::try_pin_label(
  self : LabelRegistry,
  label : LabelRef,
  instr : Instr,
) -> Unit {
  if self.labels[label.0] is Unpinned {
    self.labels[label.0] = Pinned(instr)
  }
}

///|
/// Tries to resolve the `label`.
///
/// Returns the proper `BranchOffset` in case the `label` has already been
/// pinned and returns an uninitialized `BranchOffset` otherwise.
///
/// In case the `label` has not yet been pinned the `user` is registered
/// for deferred label resolution.
pub fn LabelRegistry::try_resolve_label(
  self : LabelRegistry,
  label : LabelRef,
  user : Instr,
) -> @ir.BranchOffset raise WasmiError {
  match self.labels[label.0] {
    Pinned(target) =>
      @ir.BranchOffset::from_src_to_dst(user.to_u32(), target.to_u32()) catch {
        e => raise WasmiError::from_ir(e)
      }
    Unpinned => {
      self.users.push({ label, user, })
      @ir.BranchOffset::uninit()
    }
  }
}

///|
/// Resolves a `label` to its pinned [`Instr`].
fn LabelRegistry::resolve_label(
  self : LabelRegistry,
  label : LabelRef,
) -> Instr {
  match self.labels[label.0] {
    Pinned(instr) => instr
    Unpinned =>
      abort(
        "failed to resolve user: trying to resolve unpinned label: LabelRef(\{label.0})",
      )
  }
}

///|
/// Returns the resolved users of labels with their branch offsets (upstream
/// `resolved_users` iterator).
pub fn LabelRegistry::resolved_users(
  self : LabelRegistry,
) -> Array[(Instr, Result[@ir.BranchOffset, WasmiError])] {
  let out = []
  for next in self.users {
    let src = next.user
    let dst = self.resolve_label(next.label)
    let offset : Result[@ir.BranchOffset, WasmiError] = try
      @ir.BranchOffset::from_src_to_dst(src.to_u32(), dst.to_u32())
    catch {
      e => Err(WasmiError::from_ir(e))
    } noraise {
      v => Ok(v)
    }
    out.push((src, offset))
  }
  out
}
