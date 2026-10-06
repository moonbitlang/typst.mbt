// Port of `typst-library/src/loading/mod.rs`: data loading.

///|
/// Something we can retrieve byte data from.
pub(all) enum DataSource {
  /// A path to a file.
  Path(PathOrStr)
  /// Raw bytes.
  Bytes(Bytes)
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataSource with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataSource with Hash::{hash, hash_combine}

///|
pub impl Reflect for DataSource with fn input() {
  input_of((Ty::new() : Ty[PathOrStr])).union_with(Type(Type::bytes()))
}

///|
pub impl Reflect for DataSource with fn output() {
  output_of((Ty::new() : Ty[PathOrStr])).union_with(Type(Type::bytes()))
}

///|
pub impl Reflect for DataSource with fn castable(v) {
  reflect_castable((Ty::new() : Ty[PathOrStr]), v) || v is Bytes(_)
}

///|
pub extend DataSource with Reflect::{output, input, castable}

///|
pub impl IntoValue for DataSource with fn into_value(self) {
  match self {
    Path(v) => IntoValue::into_value(v)
    Bytes(v) => Bytes(BytesValue(v))
  }
}

///|
pub extend DataSource with IntoValue::{into_value}

///|
pub impl FromValue for DataSource with fn from_value(v) {
  if reflect_castable((Ty::new() : Ty[PathOrStr]), v) {
    Path(v.cast())
  } else if v is Bytes(BytesValue(b)) {
    Bytes(b)
  } else {
    raise HintedError(cast_error((Ty::new() : Ty[DataSource]), v))
  }
}

///|
pub extend DataSource with FromValue::{from_value}

///|
/// Loads data from a path or provided bytes (upstream `Load for
/// Spanned<DataSource>`), with `span` being the span of the source.
pub fn DataSource::load(
  self : DataSource,
  span : @syntax.Span,
  world : &World,
) -> Loaded raise SourceError {
  match self {
    Path(path) => {
      let resolved = at(span, () => path.resolve_if_some(span.id())).intern()
      let data = at(span, () => {
        world.file(resolved) catch {
          error => {
            let hinted = HintedString::new(error.to_string())
            if path is Str(string) &&
              (string.has_prefix("http://") || string.has_prefix("https://")) {
              hinted.hint("network access is not supported")
            }
            raise HintedError(hinted)
          }
        }
      })
      { source: { v: Path(resolved), span, }, data, }
    }
    Bytes(data) => { source: { v: Bytes, span, }, data, }
  }
}

///|
/// Loads data from multiple sources (upstream `Load for
/// Spanned<OneOrMultiple<DataSource>>`).
pub fn load_many(
  sources : @syntax.Spanned[Array[DataSource]],
  world : &World,
) -> Array[Loaded] raise SourceError {
  sources.v.map(source => source.load(sources.span, world))
}

///|
/// Data loaded from a [DataSource].
pub(all) struct Loaded {
  /// Details about where `data` was loaded from.
  source : @syntax.Spanned[LoadSource]
  /// The loaded data.
  data : Bytes
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Loaded with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Loaded with Hash::{hash, hash_combine}

///|
pub fn Loaded::new(
  source : @syntax.Spanned[LoadSource],
  bytes : Bytes,
) -> Loaded {
  { source, data: bytes, }
}

///|
/// A loaded [DataSource].
pub(all) enum LoadSource {
  Path(@syntax.FileId)
  Bytes
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LoadSource with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LoadSource with Hash::{hash, hash_combine}

///|
/// A value that can be read from a file.
pub(all) enum Readable {
  /// A decoded string.
  Str(String)
  /// Raw bytes.
  Bytes(Bytes)
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Readable with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Readable with Hash::{hash, hash_combine}

///|
pub fn Readable::into_bytes(self : Readable) -> Bytes {
  match self {
    Bytes(v) => v
    Str(v) => @utf8.encode(v)
  }
}

///|
pub fn Readable::into_source(self : Readable) -> DataSource {
  Bytes(self.into_bytes())
}

///|
pub impl Reflect for Readable with fn input() {
  CastInfo::Type(Type::str()).union_with(Type(Type::bytes()))
}

///|
pub impl Reflect for Readable with fn output() {
  CastInfo::Type(Type::str()).union_with(Type(Type::bytes()))
}

///|
pub impl Reflect for Readable with fn castable(v) {
  reflect_castable((Ty::new() : Ty[String]), v) || v is Bytes(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Readable with Reflect::{output, input, castable}

///|
pub impl IntoValue for Readable with fn into_value(self) {
  match self {
    Str(v) => Str(v)
    Bytes(v) => Bytes(BytesValue(v))
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Readable with IntoValue::{into_value}

///|
pub impl FromValue for Readable with fn from_value(v) {
  if reflect_castable((Ty::new() : Ty[String]), v) {
    Str(v.cast())
  } else if v is Bytes(BytesValue(b)) {
    Bytes(b)
  } else {
    raise HintedError(cast_error((Ty::new() : Ty[Readable]), v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Readable with FromValue::{from_value}

///|
pub impl Fingerprint for Loaded with fn fingerprint(self, state) {
  match self.source.v {
    Path(id) => {
      state.write_discriminant(0)
      state.write_u32(id.into_raw().to_uint())
    }
    Bytes => state.write_discriminant(1)
  }
  state.write_u64(self.source.span.0)
  state.write_usize(self.data.length())
  state.write_bytes(self.data)
}

///|
#deprecated("call as `Fingerprint::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Loaded with Fingerprint::{fingerprint}
