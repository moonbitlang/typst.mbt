// Integer newtypes with upstream's cast semantics (int.rs `cast!`s).

///|
/// Upstream `u8` (as a castable value).
pub(all) struct U8(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for U8 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for U8 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for U8 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for U8 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for U8 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < 0L {
        bail("number must be at least zero")
      } else if v > 255L {
        bail("number too large")
      }
      U8(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn U8::get(self : U8) -> Int64 {
  self.0
}

///|
/// Upstream `u16` (as a castable value).
pub(all) struct U16(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for U16 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for U16 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for U16 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for U16 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for U16 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < 0L {
        bail("number must be at least zero")
      } else if v > 65535L {
        bail("number too large")
      }
      U16(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn U16::get(self : U16) -> Int64 {
  self.0
}

///|
/// Upstream `u32` (as a castable value).
pub(all) struct U32(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for U32 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for U32 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for U32 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for U32 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for U32 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < 0L {
        bail("number must be at least zero")
      } else if v > 4294967295L {
        bail("number too large")
      }
      U32(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn U32::get(self : U32) -> Int64 {
  self.0
}

///|
/// Upstream `u64` (as a castable value).
pub(all) struct U64(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for U64 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for U64 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for U64 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for U64 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for U64 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < 0L {
        bail("number must be at least zero")
      } else if v > @int64.max_value {
        bail("number too large")
      }
      U64(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn U64::get(self : U64) -> Int64 {
  self.0
}

///|
/// Upstream `usize` (as a castable value).
pub(all) struct USize(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for USize with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for USize with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for USize with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for USize with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for USize with fn from_value(value) {
  match value {
    Int(v) => {
      if v < 0L {
        bail("number must be at least zero")
      } else if v > @int64.max_value {
        bail("number too large")
      }
      USize(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn USize::get(self : USize) -> Int64 {
  self.0
}

///|
/// Upstream `i8` (as a castable value).
pub(all) struct I8(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for I8 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for I8 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for I8 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for I8 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for I8 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < -128L || v > 127L {
        bail("number too large")
      }
      I8(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn I8::get(self : I8) -> Int64 {
  self.0
}

///|
/// Upstream `i16` (as a castable value).
pub(all) struct I16(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for I16 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for I16 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for I16 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for I16 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for I16 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < -32768L || v > 32767L {
        bail("number too large")
      }
      I16(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn I16::get(self : I16) -> Int64 {
  self.0
}

///|
/// Upstream `i32` (as a castable value).
pub(all) struct I32(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for I32 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for I32 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for I32 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for I32 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for I32 with fn from_value(value) {
  match value {
    Int(v) => {
      if v < -2147483648L || v > 2147483647L {
        bail("number too large")
      }
      I32(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn I32::get(self : I32) -> Int64 {
  self.0
}

///|
/// Upstream `NonZeroU32` (as a castable value).
pub(all) struct NonZeroU32(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for NonZeroU32 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroU32 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroU32 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for NonZeroU32 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for NonZeroU32 with fn from_value(value) {
  match value {
    Int(v) => {
      if v <= 0L {
        bail("number must be positive")
      } else if v > 4294967295L {
        bail("number too large")
      }
      NonZeroU32(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn NonZeroU32::get(self : NonZeroU32) -> Int64 {
  self.0
}

///|
/// Upstream `NonZeroU64` (as a castable value).
pub(all) struct NonZeroU64(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for NonZeroU64 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroU64 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroU64 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for NonZeroU64 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for NonZeroU64 with fn from_value(value) {
  match value {
    Int(v) => {
      if v <= 0L {
        bail("number must be positive")
      } else if v > @int64.max_value {
        bail("number too large")
      }
      NonZeroU64(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn NonZeroU64::get(self : NonZeroU64) -> Int64 {
  self.0
}

///|
/// Upstream `NonZeroUsize` (as a castable value).
pub(all) struct NonZeroUSize(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for NonZeroUSize with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroUSize with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroUSize with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for NonZeroUSize with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for NonZeroUSize with fn from_value(value) {
  match value {
    Int(v) => {
      if v <= 0L {
        bail("number must be positive")
      } else if v > @int64.max_value {
        bail("number too large")
      }
      NonZeroUSize(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn NonZeroUSize::get(self : NonZeroUSize) -> Int64 {
  self.0
}

///|
/// Upstream `NonZeroI64` (as a castable value).
pub(all) struct NonZeroI64(Int64) derive(Eq, Hash, Compare, Debug)

///|
pub impl Reflect for NonZeroI64 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroI64 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for NonZeroI64 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for NonZeroI64 with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for NonZeroI64 with fn from_value(value) {
  match value {
    Int(v) => {
      if v == 0L {
        bail("number must not be zero")
      }
      NonZeroI64(v)
    }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
pub fn NonZeroI64::get(self : NonZeroI64) -> Int64 {
  self.0
}
