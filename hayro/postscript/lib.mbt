// Port of `hayro-postscript/src/lib.rs`.
//
// A lightweight PostScript scanner.
//
// This package provides a scanner for tokenizing PostScript programs into
// typed objects. It currently only implements a very small subset of the
// PostScript language, with the main goal of being enough to parse CMAP
// files, but the scope _might_ be expanded upon in the future.
//
// The supported types include integers and real numbers, name objects,
// strings and arrays. Unsupported is anything else, including dictionaries,
// procedures, etc. An error will be returned in case any of these is
// encountered.

///|
/// A PostScript scanner that parses [`Object`]s from a byte stream.
pub struct Scanner {
  priv reader : Reader
}

///|
/// Create a new scanner over the given bytes of a PostScript program.
pub fn Scanner::new(data : BytesView) -> Scanner {
  { reader: Reader::new(data), }
}

///|
/// Returns `true` if there are no more objects to parse.
pub fn Scanner::at_end(self : Scanner) -> Bool {
  at_end(self.reader)
}

///|
/// Parse the next object.
pub fn Scanner::parse_object(self : Scanner) -> Result[Object, PsError] {
  read_object(self.reader)
}

///|
/// Parse the next object as a [`Number`].
pub fn Scanner::parse_number(self : Scanner) -> Result[Number, PsError] {
  match self.parse_object() {
    Ok(Number(n)) => Ok(n)
    Ok(_) => Err(SyntaxError)
    Err(e) => Err(e)
  }
}

///|
/// Parse the next object as a [`Name`].
pub fn Scanner::parse_name(self : Scanner) -> Result[Name, PsError] {
  match self.parse_object() {
    Ok(Name(n)) => Ok(n)
    Ok(_) => Err(SyntaxError)
    Err(e) => Err(e)
  }
}

///|
/// Parse the next object as a [`PsString`].
pub fn Scanner::parse_string(self : Scanner) -> Result[PsString, PsError] {
  match self.parse_object() {
    Ok(String(s)) => Ok(s)
    Ok(_) => Err(SyntaxError)
    Err(e) => Err(e)
  }
}

///|
/// Parse the next object as a [`PsArray`].
pub fn Scanner::parse_array(self : Scanner) -> Result[PsArray, PsError] {
  match self.parse_object() {
    Ok(Array(a)) => Ok(a)
    Ok(_) => Err(SyntaxError)
    Err(e) => Err(e)
  }
}
