// Port of wasmi_ir 1.0.9 `error.rs`.

///|
/// An error that may be occurred when operating with some Wasmi IR primitives.
pub(all) suberror Error {
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
pub impl Show for Error with output(self, logger) {
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
/// Error when trying to convert a value into an immediate that cannot
/// represent it (upstream `OutOfBoundsConst`).
pub(all) suberror OutOfBoundsConst derive(Eq, Show)
