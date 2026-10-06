// Port of wasmi_ir 1.0.9 `error.rs`.

///|
/// An error that may be occurred when operating with some Wasmi IR primitives.
pub(all) suberror IrError {
  /// Encountered when trying to create a [`Slot`] from an out of bounds integer.
  StackSlotOutOfBounds
  /// Encountered when trying to create a [`BranchOffset`] from an out of bounds integer.
  BranchOffsetOutOfBounds
  /// Encountered when trying to create a [`Comparator`] from an out of bounds integer.
  ComparatorOutOfBounds
  /// Encountered when trying to create a [`BlockFuel`] from an out of bounds integer.
  BlockFuelOutOfBounds
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IrError with Eq::{not_equal, equal}

///|
pub impl Show for IrError with fn output(self, logger) {
  logger.write_string(
    match self {
      StackSlotOutOfBounds => "stack slot index out of bounds"
      BranchOffsetOutOfBounds => "branch offset out of bounds"
      ComparatorOutOfBounds => "comparator out of bounds"
      BlockFuelOutOfBounds => "block fuel out of bounds"
    },
  )
}

///|
pub extend IrError with Show::{to_string, output}

///|
/// Error when trying to convert a value into an immediate that cannot
/// represent it (upstream `OutOfBoundsConst`).
pub(all) suberror OutOfBoundsConst derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutOfBoundsConst with Eq::{not_equal, equal}

///|
/// What `derive(Show)` printed (deprecated as a derive).
pub impl Show for OutOfBoundsConst with fn output(_self, logger) {
  logger.write_string("OutOfBoundsConst")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutOfBoundsConst with Show::{to_string, output}
