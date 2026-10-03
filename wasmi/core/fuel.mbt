// Port of `wasmi_core/src/fuel.rs`.

///|
/// Fuel costs for Wasmi IR instructions.
pub(open) trait FuelCosts {
  /// Returns the base fuel costs for all Wasmi IR instructions.
  fn base(Self) -> UInt64

  /// Returns the base fuel costs for all Wasmi IR `load` instructions.
  fn load(Self) -> UInt64 = _

  /// Returns the base fuel costs for all Wasmi IR `instance` instructions.
  ///
  /// # Note
  ///
  /// Entity-based instructions access or modify instance related data,
  /// such as globals, memories, tables or functions.
  fn instance(Self) -> UInt64 = _

  /// Returns the base fuel costs for all Wasmi IR `store` instructions.
  fn store(Self) -> UInt64 = _

  /// Returns the base fuel costs for all Wasmi IR `call` instructions.
  fn call(Self) -> UInt64 = _

  /// Returns the base fuel costs for all Wasmi IR `simd` instructions.
  fn simd(Self) -> UInt64 = _

  /// Returns the amount of bytes that can be copied for a single unit of fuel.
  ///
  /// Must not be zero (upstream `NonZeroU64`).
  fn bytes_per_fuel(Self) -> UInt64
}

///|
impl FuelCosts with fn load(self) {
  self.base()
}

///|
impl FuelCosts with fn instance(self) {
  self.base()
}

///|
impl FuelCosts with fn store(self) {
  self.base()
}

///|
impl FuelCosts with fn call(self) {
  self.base()
}

///|
impl FuelCosts with fn simd(self) {
  self.base()
}

///|
/// Implementation of default [`FuelCostsProvider`].
priv struct DefaultFuelCosts {}

///|
impl FuelCosts for DefaultFuelCosts with fn base(_self) {
  1
}

///|
impl FuelCosts for DefaultFuelCosts with fn bytes_per_fuel(_self) {
  64
}

///|
/// Type storing all kinds of fuel costs of instructions.
pub struct FuelCostsProvider {
  /// Optional custom fuel costs.
  custom : &FuelCosts?
}

///|
pub impl Default for FuelCostsProvider with fn default() {
  { custom: None, }
}

///|
/// Creates a [`FuelCostsProvider`] with custom fuel costs.
pub fn FuelCostsProvider::new(custom : &FuelCosts?) -> FuelCostsProvider {
  { custom, }
}

///|
pub impl Show for FuelCostsProvider with fn output(self, logger) {
  logger.write_string(
    "FuelCostsProvider { base: \{self.base()}, instance: \{self.instance()}, load: \{self.load()}, store: \{self.store()}, call: \{self.call()}, simd: \{self.simd()}, bytes_per_fuel: \{self.bytes_per_fuel()} }",
  )
}

///|
/// Applies `f` to either `self.custom` or [`DefaultFuelCosts`] if `self.custom` is `None`.
fn FuelCostsProvider::apply(
  self : FuelCostsProvider,
  f : (&FuelCosts) -> UInt64,
) -> UInt64 {
  match self.custom {
    Some(costs) => f(costs)
    None => f(DefaultFuelCosts::{ })
  }
}

///|
/// Returns the base fuel costs for all Wasmi IR instructions.
pub fn FuelCostsProvider::base(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.base())
}

///|
/// Returns the fuel costs for all Wasmi IR `instance` related instructions.
pub fn FuelCostsProvider::instance(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.instance())
}

///|
/// Returns the fuel costs for all Wasmi IR `load` instructions.
pub fn FuelCostsProvider::load(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.load())
}

///|
/// Returns the fuel costs for all Wasmi IR `store` instructions.
pub fn FuelCostsProvider::store(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.store())
}

///|
/// Returns the fuel costs for all Wasmi IR `call` instructions.
pub fn FuelCostsProvider::call(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.call())
}

///|
/// Returns the fuel costs for all Wasmi IR `simd` instructions.
pub fn FuelCostsProvider::simd(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.simd())
}

///|
/// Returns the number of bytes that can be copied per unit of fuel.
fn FuelCostsProvider::bytes_per_fuel(self : FuelCostsProvider) -> UInt64 {
  self.apply(c => c.bytes_per_fuel())
}

///|
/// Returns the fuel costs for `len_bytes` byte copies in Wasmi IR.
///
/// # Note
///
/// - On overflow this returns [`u64::MAX`].
/// - The following Wasmi IR instructions may make use of this:
///     - `memory.grow`
///     - `memory.copy`
///     - `memory.fill`
///     - `memory.init`
pub fn FuelCostsProvider::fuel_for_copying_bytes(
  self : FuelCostsProvider,
  len_bytes : UInt64,
) -> UInt64 {
  len_bytes / self.bytes_per_fuel()
}

///|
/// Returns the fuel costs for copying `len_values` [`UntypedVal`] items.
///
/// # Note
///
/// - On overflow this returns [`u64::MAX`].
/// - [`UntypedVal`] might be 64-bit or 128-bit depending on the crate's config.
/// - The following Wasmi IR instructions may make use of this:
///     - calls (parameter passing)
///     - `copy_span`
///     - `copy_many`
///     - `return_span`
///     - `return_many`
///     - `table.grow` (+ variants)
///     - `table.copy` (+ variants)
///     - `table.fill` (+ variants)
///     - `table.init` (+ variants)
pub fn FuelCostsProvider::fuel_for_copying_values(
  self : FuelCostsProvider,
  len_values : UInt64,
) -> UInt64 {
  // `mem::size_of::<UntypedVal>()` with the `simd` feature.
  let size_of_val = 16UL
  let copied_bytes = if len_values > 0xFFFF_FFFF_FFFF_FFFFUL / size_of_val {
    0xFFFF_FFFF_FFFF_FFFFUL
  } else {
    len_values * size_of_val
  }
  self.fuel_for_copying_bytes(copied_bytes)
}

///|
/// An error that may be encountered when using [`Fuel`].
pub(all) suberror FuelError {
  /// Returned by some [`Fuel`] methods when fuel metering is disabled.
  FuelMeteringDisabled
  /// Raised when trying to consume more fuel than is available.
  OutOfFuel(required_fuel~ : UInt64)
} derive(Debug)

///|
pub impl Show for FuelError with fn output(self, logger) {
  match self {
    FuelMeteringDisabled => logger.write_string("fuel metering is disabled")
    OutOfFuel(required_fuel~) =>
      logger.write_string("ouf of fuel. required=\{required_fuel}")
  }
}

///|
/// Returns an error indicating that fuel metering has been disabled.
pub fn FuelError::fuel_metering_disabled() -> FuelError {
  FuelMeteringDisabled
}

///|
/// Returns an error indicating that too much fuel has been consumed.
pub fn FuelError::out_of_fuel(required_fuel : UInt64) -> FuelError {
  OutOfFuel(required_fuel~)
}

///|
/// The remaining and consumed fuel counters.
pub struct Fuel {
  /// The remaining fuel.
  mut remaining : UInt64
  /// This is `true` if fuel metering is enabled.
  enabled : Bool
  /// The fuel costs.
  costs : FuelCostsProvider
}

///|
/// Creates a new [`Fuel`].
pub fn Fuel::new(enabled : Bool, costs : FuelCostsProvider) -> Fuel {
  { remaining: 0, enabled, costs, }
}

///|
/// Returns `true` if fuel metering is enabled.
fn Fuel::is_fuel_metering_enabled(self : Fuel) -> Bool {
  self.enabled
}

///|
/// Returns `Ok` if fuel metering is enabled.
///
/// Returns descriptive [`FuelError`] otherwise.
fn Fuel::check_fuel_metering_enabled(self : Fuel) -> Unit raise FuelError {
  if !self.is_fuel_metering_enabled() {
    raise FuelError::fuel_metering_disabled()
  }
}

///|
/// Sets the remaining fuel to `fuel`.
///
/// # Errors
///
/// If fuel metering is disabled.
pub fn Fuel::set_fuel(self : Fuel, fuel : UInt64) -> Unit raise FuelError {
  self.check_fuel_metering_enabled()
  self.remaining = fuel
}

///|
/// Returns the remaining fuel.
///
/// # Errors
///
/// If fuel metering is disabled.
pub fn Fuel::get_fuel(self : Fuel) -> UInt64 raise FuelError {
  self.check_fuel_metering_enabled()
  self.remaining
}

///|
/// Synthetically consumes an amount of [`Fuel`].
///
/// Returns the remaining amount of [`Fuel`] after this operation.
///
/// # Note
///
/// - This does _not_ check if fuel metering is enabled.
/// - This API is intended for use cases where it is clear that fuel metering is
///   enabled and where a check would incur unnecessary overhead in a hot path.
///   An example of this is the execution of consume fuel instructions since
///   those only exist if fuel metering is enabled.
///
/// # Errors
///
/// If out of fuel.
pub fn Fuel::consume_fuel_unchecked(
  self : Fuel,
  delta : UInt64,
) -> UInt64 raise FuelError {
  if delta > self.remaining {
    raise FuelError::out_of_fuel(delta)
  }
  self.remaining = self.remaining - delta
  self.remaining
}

///|
/// Consumes an amount of [`Fuel`].
///
/// Returns the remaining amount of [`Fuel`] after this operation.
///
/// # Errors
///
/// - If fuel metering is disabled.
/// - If out of fuel.
pub fn Fuel::consume_fuel(
  self : Fuel,
  f : (FuelCostsProvider) -> UInt64,
) -> UInt64 raise FuelError {
  self.check_fuel_metering_enabled()
  self.consume_fuel_unchecked(f(self.costs))
}

///|
/// Consumes an amount of [`Fuel`] if fuel metering is enabled.
///
/// # Note
///
/// This does nothing if fuel metering is disabled.
///
/// # Errors
///
/// - If out of fuel.
pub fn Fuel::consume_fuel_if(
  self : Fuel,
  f : (FuelCostsProvider) -> UInt64,
) -> Unit raise FuelError {
  if !self.is_fuel_metering_enabled() {
    return
  }
  self.consume_fuel_unchecked(f(self.costs)) |> ignore
}
