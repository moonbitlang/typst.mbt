// Port of `typst-library/src/loading/read.rs`.

///|
fn impl_read__encoding_default() -> Encoding? {
  Some(Utf8)
}

///|
/// Reads plain text or data from a file.
///
/// By default, the file will be read as UTF-8 and returned as a string.
///
/// If you specify `{encoding: none}`, this returns raw bytes instead.
fn impl_read(
  engine : Engine,
  path_ : @syntax.Spanned[PathOrStr],
  encoding_ : Encoding?,
) -> Readable raise SourceError {
  let loaded = DataSource::Path(path_.v).load(path_.span, engine.world)
  match encoding_ {
    None => Bytes(loaded.data)
    Some(Utf8) => Str(within(loaded, () => bytes_as_str(loaded.data)))
  }
}

///|
/// An encoding of a file.
pub(all) enum Encoding {
  /// The Unicode UTF-8 encoding.
  Utf8
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for Encoding with fn input() {
  Union([Value(Str("utf8"), "The Unicode UTF-8 encoding.")])
}

///|
pub impl Reflect for Encoding with fn output() {
  input_of((Ty::new() : Ty[Encoding]))
}

///|
pub impl Reflect for Encoding with fn castable(v) {
  v is Str("utf8")
}

///|
pub impl IntoValue for Encoding with fn into_value(self) {
  match self {
    Utf8 => Str("utf8")
  }
}

///|
pub impl FromValue for Encoding with fn from_value(v) {
  match v {
    Str("utf8") => Utf8
    v => raise HintedError(cast_error((Ty::new() : Ty[Encoding]), v))
  }
}
