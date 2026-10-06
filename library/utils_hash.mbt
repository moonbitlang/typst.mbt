// Port of `typst-utils/src/hash.rs` (`hash128`) and the `siphasher` crate's
// `SipHasher13` with 128-bit output, which upstream uses for all
// identity-relevant hashes (locations, convergence checks, query caches).
//
// MoonBit's builtin `Hash` produces 32-bit hashes with a process-specific
// hasher, so it is not usable for stable identities. Instead, types that take
// part in identity hashing implement [Fingerprint], a structural hash that
// follows what upstream's `Hash` impls feed into the hasher. The resulting
// numbers are not identical to Rust's (payload encodings differ), but they are
// deterministic and collision-resistant.

///|
/// An unsigned 128-bit integer (upstream `u128`), used for hashes.
pub(all) struct U128 {
  /// The upper 64 bits.
  hi : UInt64
  /// The lower 64 bits.
  lo : UInt64
} derive(Eq, Hash, Compare, Default, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend U128 with Default::{default}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with @debug.Debug::{to_repr}

///|
/// Create a 128-bit integer from a 64-bit one.
pub fn U128::from_u64(lo : UInt64) -> U128 {
  { hi: 0, lo, }
}

///|
/// Zero.
pub let u128_zero : U128 = { hi: 0, lo: 0, }

///|
pub impl Show for U128 with fn output(self, logger) {
  logger.write_string("0x")
  let hex = (v : UInt64) => {
    let digits = "0123456789abcdef"
    let buf = StringBuilder()
    for i = 15; i >= 0; i = i - 1 {
      let nibble = ((v >> (i * 4)) & 0xf).to_int()
      buf.write_char(digits.unsafe_get(nibble).unsafe_to_char())
    }
    buf.to_string()
  }
  logger.write_string(hex(self.hi))
  logger.write_string(hex(self.lo))
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with Show::{to_string, output}

///|
/// A SipHash-1-3 hasher with 128-bit output and zero keys (upstream
/// `siphasher::sip128::SipHasher13::new()`).
pub struct SipHasher128 {
  priv mut v0 : UInt64
  priv mut v1 : UInt64
  priv mut v2 : UInt64
  priv mut v3 : UInt64
  /// Unprocessed bytes (little endian, `ntail` of them).
  priv mut tail : UInt64
  priv mut ntail : Int
  /// Total number of bytes written.
  priv mut length : UInt64
}

///|
/// Create a new hasher.
pub fn SipHasher128::new() -> SipHasher128 {
  let k0 : UInt64 = 0
  let k1 : UInt64 = 0
  {
    v0: k0 ^ 0x736f6d6570736575UL,
    // The 128-bit variant xors `0xee` into `v1`.
    v1: k1 ^ 0x646f72616e646f6dUL ^ 0xeeUL,
    v2: k0 ^ 0x6c7967656e657261UL,
    v3: k1 ^ 0x7465646279746573UL,
    tail: 0,
    ntail: 0,
    length: 0,
  }
}

///|
fn rotl(x : UInt64, b : Int) -> UInt64 {
  (x << b) | (x >> (64 - b))
}

///|
fn SipHasher128::round(self : SipHasher128) -> Unit {
  self.v0 = self.v0 + self.v1
  self.v1 = rotl(self.v1, 13)
  self.v1 = self.v1 ^ self.v0
  self.v0 = rotl(self.v0, 32)
  self.v2 = self.v2 + self.v3
  self.v3 = rotl(self.v3, 16)
  self.v3 = self.v3 ^ self.v2
  self.v0 = self.v0 + self.v3
  self.v3 = rotl(self.v3, 21)
  self.v3 = self.v3 ^ self.v0
  self.v2 = self.v2 + self.v1
  self.v1 = rotl(self.v1, 17)
  self.v1 = self.v1 ^ self.v2
  self.v2 = rotl(self.v2, 32)
}

///|
/// Process one 64-bit message word (one compression round for SipHash-1-3).
fn SipHasher128::compress(self : SipHasher128, m : UInt64) -> Unit {
  self.v3 = self.v3 ^ m
  self.round()
  self.v0 = self.v0 ^ m
}

///|
/// Write a single byte.
pub fn SipHasher128::write_u8(self : SipHasher128, b : Byte) -> Unit {
  self.tail = self.tail | (b.to_uint64() << (8 * self.ntail))
  self.ntail += 1
  self.length += 1
  if self.ntail == 8 {
    self.compress(self.tail)
    self.tail = 0
    self.ntail = 0
  }
}

///|
/// Write a 64-bit integer (little endian, like Rust's `write_u64`).
pub fn SipHasher128::write_u64(self : SipHasher128, v : UInt64) -> Unit {
  if self.ntail == 0 {
    self.compress(v)
    self.length += 8
  } else {
    // Merge into the unaligned tail.
    let n = self.ntail
    let word = self.tail | (v << (8 * n))
    self.compress(word)
    self.tail = v >> (64 - 8 * n)
    self.length += 8
  }
}

///|
/// Write bytes.
pub fn SipHasher128::write_bytes(
  self : SipHasher128,
  bytes : BytesView,
) -> Unit {
  for b in bytes {
    self.write_u8(b)
  }
}

///|
/// Write a 32-bit integer.
pub fn SipHasher128::write_u32(self : SipHasher128, v : UInt) -> Unit {
  for i in 0..<4 {
    self.write_u8((v >> (8 * i)).to_byte())
  }
}

///|
/// Write a `usize` (hashed as `u64`, like upstream on 64-bit platforms).
pub fn SipHasher128::write_usize(self : SipHasher128, v : Int) -> Unit {
  self.write_u64(v.to_int64().reinterpret_as_uint64())
}

///|
/// Write a signed 64-bit integer.
pub fn SipHasher128::write_i64(self : SipHasher128, v : Int64) -> Unit {
  self.write_u64(v.reinterpret_as_uint64())
}

///|
/// Write a 128-bit integer.
pub fn SipHasher128::write_u128(self : SipHasher128, v : U128) -> Unit {
  self.write_u64(v.lo)
  self.write_u64(v.hi)
}

///|
/// Write a boolean (as one byte).
pub fn SipHasher128::write_bool(self : SipHasher128, v : Bool) -> Unit {
  self.write_u8(if v { b'\x01' } else { b'\x00' })
}

///|
/// Write an enum discriminant (Rust hashes `isize` discriminants).
pub fn SipHasher128::write_discriminant(self : SipHasher128, d : Int) -> Unit {
  self.write_usize(d)
}

///|
/// Write a float by its bit pattern (upstream hashes `f64::to_bits`), so that
/// `0.0` and `-0.0` differ.
pub fn SipHasher128::write_f64(self : SipHasher128, v : Double) -> Unit {
  self.write_u64(v.reinterpret_as_uint64())
}

///|
/// Write a string: its UTF-8 bytes followed by `0xff` (like Rust's `str`
/// hash).
pub fn SipHasher128::write_str(self : SipHasher128, s : StringView) -> Unit {
  for c in s {
    let code = c.to_int()
    if code < 0x80 {
      self.write_u8(code.to_byte())
    } else if code < 0x800 {
      self.write_u8((0xc0 | (code >> 6)).to_byte())
      self.write_u8((0x80 | (code & 0x3f)).to_byte())
    } else if code < 0x10000 {
      self.write_u8((0xe0 | (code >> 12)).to_byte())
      self.write_u8((0x80 | ((code >> 6) & 0x3f)).to_byte())
      self.write_u8((0x80 | (code & 0x3f)).to_byte())
    } else {
      self.write_u8((0xf0 | (code >> 18)).to_byte())
      self.write_u8((0x80 | ((code >> 12) & 0x3f)).to_byte())
      self.write_u8((0x80 | ((code >> 6) & 0x3f)).to_byte())
      self.write_u8((0x80 | (code & 0x3f)).to_byte())
    }
  }
  self.write_u8(b'\xff')
}

///|
/// Finish the hash, returning the 128-bit result. The hasher must not be
/// used afterwards.
pub fn SipHasher128::finish128(self : SipHasher128) -> U128 {
  let b = ((self.length & 0xff) << 56) | self.tail
  self.compress(b)
  self.v2 = self.v2 ^ 0xee
  self.round()
  self.round()
  self.round()
  let h1 = self.v0 ^ self.v1 ^ self.v2 ^ self.v3
  self.v1 = self.v1 ^ 0xdd
  self.round()
  self.round()
  self.round()
  let h2 = self.v0 ^ self.v1 ^ self.v2 ^ self.v3
  // `Hash128::as_u128` puts `h2` into the upper half.
  { hi: h2, lo: h1, }
}

///|
/// A structural, identity-relevant hash (upstream's `Hash` impls as consumed
/// by `typst_utils::hash128`). Implementations feed exactly the information
/// upstream hashes, including enum discriminants, so that e.g. `0` and `0.0`
/// or content with different spans or locations hash differently.
pub(open) trait Fingerprint {
  fn fingerprint(Self, SipHasher128) -> Unit
}

///|
/// Feed a value into the hasher.
pub fn[T : Fingerprint] SipHasher128::write(
  self : SipHasher128,
  value : T,
) -> Unit {
  value.fingerprint(self)
}

///|
/// Flags of the fingerprint being computed (not upstream; see `memo.mbt`):
/// [fingerprint_lossy] if it contains a value whose [Fingerprint] does not
/// capture all of the data that upstream's `Hash` covers (no impl does at
/// the moment; such an impl must call [mark_fingerprint_lossy]),
/// [fingerprint_identity] if it contains a value that compares by identity
/// (host closures and modules, whose fingerprints are a key and structural;
/// closures do not: they compare by their hash, like upstream's). Equal
/// fingerprints with flags do not prove interchangeable values, and a lossy
/// fingerprint gives elements a location key that upstream would not give
/// them.
let fingerprint_flags : Ref[Int] = { val: 0, }

///|
/// See [fingerprint_flags].
pub let fingerprint_lossy : Int = 1

///|
/// See [fingerprint_flags].
pub let fingerprint_identity : Int = 2

///|
/// See [fingerprint_flags]: the fingerprint contains a host closure (a
/// [HostFunc]; it also sets [fingerprint_identity]).
pub let fingerprint_host : Int = 4

///|
/// The collector of the host closures visited by fingerprint computations
/// (see [fingerprint_hosts_in]).
let fingerprint_hosts : Ref[Array[HostFunc]?] = { val: None, }

///|
/// Runs `f` (a fingerprint computation) and returns the host closures it
/// visited, in order. Host closures compare by identity, which a
/// fingerprint cannot express: their fingerprint is a key that the host
/// promises to be unique. Where identity matters (the validation of
/// recorded introspector reads), the visited closures are compared too.
pub fn fingerprint_hosts_in(f : () -> Unit) -> Array[HostFunc] {
  let outer = fingerprint_hosts.val
  let hosts = []
  fingerprint_hosts.val = Some(hosts)
  f()
  fingerprint_hosts.val = outer
  hosts
}

///|
/// A collector armed for the next [hash128_output] (the validation of a
/// recorded introspector read sets it around the replay).
let fingerprint_output_hosts : Ref[Array[HostFunc]?] = { val: None, }

///|
/// [hash128] of the result of a replayed introspector read. If a collector
/// is armed, it receives the host closures of this fingerprint and only of
/// this one: fingerprints computed while the result was produced (the
/// argument is evaluated before the call) are not collected.
fn[T : Fingerprint] hash128_output(value : T) -> U128 {
  match fingerprint_output_hosts.val {
    None => hash128(value)
    Some(hosts) => {
      fingerprint_output_hosts.val = None
      let outer = fingerprint_hosts.val
      fingerprint_hosts.val = Some(hosts)
      let hash = hash128(value)
      fingerprint_hosts.val = outer
      hash
    }
  }
}

///|
/// Record that the value being fingerprinted is not fully captured by its
/// fingerprint.
pub fn mark_fingerprint_lossy() -> Unit {
  fingerprint_flags.val = fingerprint_flags.val | fingerprint_lossy
}

///|
/// Record flags for the value being fingerprinted (e.g. from a cache).
pub fn mark_fingerprint_flags(flags : Int) -> Unit {
  fingerprint_flags.val = fingerprint_flags.val | flags
}

///|
/// Runs `f` and returns the flags of what it fingerprinted (the flags of an
/// enclosing fingerprint computation are kept).
pub fn fingerprint_flags_in(f : () -> Unit) -> Int {
  let outer = fingerprint_flags.val
  fingerprint_flags.val = 0
  f()
  let flags = fingerprint_flags.val
  fingerprint_flags.val = outer | flags
  flags
}

///|
/// Runs `f` and returns whether it fingerprinted a lossy value.
pub fn fingerprint_lossy_in(f : () -> Unit) -> Bool {
  (fingerprint_flags_in(f) & fingerprint_lossy) != 0
}

///|
/// Calculate a 128-bit SipHash of a value (upstream `typst_utils::hash128`).
pub fn[T : Fingerprint] hash128(value : T) -> U128 {
  let state = SipHasher128::new()
  state.write(value)
  state.finish128()
}

///|
pub impl Fingerprint for Unit with fn fingerprint(_, _) {
  ()
}

///|
pub impl Fingerprint for Bool with fn fingerprint(self, state) {
  state.write_bool(self)
}

///|
pub impl Fingerprint for Int with fn fingerprint(self, state) {
  state.write_usize(self)
}

///|
pub impl Fingerprint for Int64 with fn fingerprint(self, state) {
  state.write_i64(self)
}

///|
pub impl Fingerprint for UInt64 with fn fingerprint(self, state) {
  state.write_u64(self)
}

///|
pub impl Fingerprint for UInt with fn fingerprint(self, state) {
  state.write_u32(self)
}

///|
pub impl Fingerprint for Double with fn fingerprint(self, state) {
  state.write_f64(self)
}

///|
pub impl Fingerprint for String with fn fingerprint(self, state) {
  state.write_str(self)
}

///|
pub impl Fingerprint for U128 with fn fingerprint(self, state) {
  state.write_u128(self)
}

///|
#deprecated("call as `Fingerprint::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend U128 with Fingerprint::{fingerprint}

///|
pub impl[T : Fingerprint] Fingerprint for T? with fn fingerprint(self, state) {
  match self {
    None => state.write_discriminant(0)
    Some(v) => {
      state.write_discriminant(1)
      state.write(v)
    }
  }
}

///|
pub impl[T : Fingerprint, E : Fingerprint] Fingerprint for Result[T, E] with fn fingerprint(
  self,
  state,
) {
  match self {
    Ok(v) => {
      state.write_discriminant(0)
      state.write(v)
    }
    Err(e) => {
      state.write_discriminant(1)
      state.write(e)
    }
  }
}

///|
/// Slices hash their length followed by their items.
pub impl[T : Fingerprint] Fingerprint for Array[T] with fn fingerprint(
  self,
  state,
) {
  state.write_usize(self.length())
  for item in self {
    state.write(item)
  }
}

///|
pub impl[A : Fingerprint, B : Fingerprint] Fingerprint for (A, B) with fn fingerprint(
  self,
  state,
) {
  state.write(self.0)
  state.write(self.1)
}

///|
pub impl[A : Fingerprint, B : Fingerprint, C : Fingerprint] Fingerprint for (
  A,
  B,
  C,
) with fn fingerprint(self, state) {
  state.write(self.0)
  state.write(self.1)
  state.write(self.2)
}

///|
pub impl[A : Fingerprint, B : Fingerprint, C : Fingerprint, D : Fingerprint] Fingerprint for (
  A,
  B,
  C,
  D,
) with fn fingerprint(self, state) {
  state.write(self.0)
  state.write(self.1)
  state.write(self.2)
  state.write(self.3)
}

///|
/// Hash a value that has no structural [Fingerprint] yet by its repr and its
/// builtin hash. Used for leaf types whose port is in flux (e.g. colors).
pub fn[T : Hash] SipHasher128::write_leaf(
  self : SipHasher128,
  repr : String,
  value : T,
) -> Unit {
  self.write_str(repr)
  self.write_u32(value.hash().reinterpret_as_uint())
}

///|
/// A lazily computed fingerprint of immutable data, cached with the object
/// that owns the data (upstream `typst_utils::LazyHash`), together with the
/// [fingerprint_flags] of the data.
///
/// The owner's data must not change once it was fingerprinted (upstream
/// `LazyHash` only hands out its value mutably by resetting the hash):
/// closures, modules and the frames of tilings are values that evaluation
/// never modifies after they were built, although their fields are
/// reachable through the public API. An owner that does modify its data
/// calls [LazyFingerprint::reset].
///
/// Evaluation cannot build data that (indirectly) holds itself, but the API
/// can (a module in its own scope). Such cycles terminate: an owner that is
/// reached again while its fingerprint is computed is written as a marker.
/// A fingerprint that was cut short this way by an owner further up is not
/// cached (it is neither the whole data nor are its flags complete); the
/// owner where the cycle closes is, with the flags of everything in it.
pub struct LazyFingerprint {
  priv mut cached : Bool
  /// The depth of the computation of this fingerprint among the running
  /// ones ([lazy_depth]), or zero if it is not being computed.
  priv mut busy : Int
  priv mut hash : U128
  priv mut flags : Int
}

///|
/// The number of [LazyFingerprint] computations that are running (nested).
let lazy_depth : Ref[Int] = { val: 0, }

///|
/// The smallest depth of a running computation that was reached again
/// (see [LazyFingerprint]): every computation deeper than it was cut short.
let lazy_cut : Ref[Int] = { val: lazy_no_cut, }

///|
let lazy_no_cut : Int = 0x7fffffff

///|
/// Whether the fingerprint computation that just ended inside a running
/// [LazyFingerprint] computation may have been cut short by a cycle, so
/// that its result must not be cached. (Conservative: a cycle found earlier
/// in the same owner counts too. Outside of running computations it is
/// false.)
fn lazy_fingerprint_cut() -> Bool {
  lazy_cut.val != lazy_no_cut
}

///|
/// An empty cache.
pub fn LazyFingerprint::new() -> LazyFingerprint {
  { cached: false, busy: 0, hash: u128_zero, flags: 0, }
}

///|
/// The cache is not part of the value that owns it.
pub impl Eq for LazyFingerprint with fn equal(_, _) {
  true
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LazyFingerprint with Eq::{not_equal, equal}

///|
pub impl Hash for LazyFingerprint with fn hash_combine(_, _) {
  ()
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LazyFingerprint with Hash::{hash, hash_combine}

///|
/// Forget the cached fingerprint (the owner's data is about to change).
pub fn LazyFingerprint::reset(self : LazyFingerprint) -> Unit {
  self.cached = false
}

///|
/// Feeds the cached hash into `state`, if there is one. Returns whether it
/// did; otherwise the caller computes it with [LazyFingerprint::write].
///
/// While host closures are collected ([fingerprint_hosts_in]), a cached
/// hash of data that holds some is not used: the collector must visit them.
pub fn LazyFingerprint::write_cached(
  self : LazyFingerprint,
  state : SipHasher128,
) -> Bool {
  if self.cached &&
    !(fingerprint_hosts.val is Some(_) && (self.flags & fingerprint_host) != 0) {
    mark_fingerprint_flags(self.flags)
    state.write_u128(self.hash)
    true
  } else {
    false
  }
}

///|
/// Feeds the 128-bit hash of what `f` writes into `state` (like upstream's
/// `Hash for LazyHash`, which writes the `u128`) and caches it with the
/// flags of what `f` fingerprinted.
pub fn LazyFingerprint::write(
  self : LazyFingerprint,
  state : SipHasher128,
  f : (SipHasher128) -> Unit,
) -> Unit {
  if !self.write_cached(state) {
    self.compute(state, f) |> ignore
  }
}

///|
/// [LazyFingerprint::write] without a usable cache. Returns the flags of the
/// data.
fn LazyFingerprint::compute(
  self : LazyFingerprint,
  state : SipHasher128,
  f : (SipHasher128) -> Unit,
) -> Int {
  if self.busy != 0 {
    // A cycle: everything between the owner and here is cut short.
    if self.busy < lazy_cut.val {
      lazy_cut.val = self.busy
    }
    state.write_discriminant(-1)
    return 0
  }
  let depth = lazy_depth.val + 1
  lazy_depth.val = depth
  self.busy = depth
  let inner = SipHasher128::new()
  let flags = fingerprint_flags_in(() => f(inner))
  self.busy = 0
  lazy_depth.val = depth - 1
  // Cut short by an owner further up; the cycles that close here are whole.
  let cut = lazy_cut.val < depth
  if !cut {
    lazy_cut.val = lazy_no_cut
  }
  if self.cached {
    // Only the collector of host closures needed the visit: the data and
    // its fingerprint are what they were.
    mark_fingerprint_flags(self.flags)
    state.write_u128(self.hash)
    return self.flags
  }
  let hash = inner.finish128()
  if !cut {
    self.hash = hash
    self.flags = flags
    self.cached = true
  }
  state.write_u128(hash)
  flags
}

///|
/// The flags of the fingerprint (computing it with `f` if needed).
pub fn LazyFingerprint::flags(
  self : LazyFingerprint,
  f : (SipHasher128) -> Unit,
) -> Int {
  if self.cached {
    self.flags
  } else {
    self.compute(SipHasher128::new(), f)
  }
}

///|
/// Syntax nodes are hashed through [@syntax.SyntaxNode::hash_into].
pub impl @syntax.NodeHasher for SipHasher128 with fn write_u64(self, v) {
  SipHasher128::write_u64(self, v)
}

///|
pub impl @syntax.NodeHasher for SipHasher128 with fn write_str(self, s) {
  SipHasher128::write_str(self, s)
}
