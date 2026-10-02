// Part of `hayro-syntax/src/crypto/mod.rs`.
//
// Deviation: decryption (RC4/AES with the standard security handler) is not
// ported yet. Documents with an `Encrypt` dictionary fail to load with
// `DecryptionError::UnsupportedAlgorithm` unless upstream would reject them
// for another reason first.

///|
/// An error that occurred during decryption.
pub(all) enum DecryptionError {
  /// The ID entry is missing in the PDF.
  MissingIDEntry
  /// The PDF is password-protected and no password (or a wrong one) was
  /// provided.
  PasswordProtected
  /// The PDF has invalid encryption.
  InvalidEncryption
  /// The PDF uses an unsupported encryption algorithm.
  UnsupportedAlgorithm
} derive(Eq, Debug)

///|
pub(all) enum DecryptionTarget {
  String
  Stream
} derive(Eq, Debug)

///|
priv enum Decryptor {
  NoDecryptor
}

///|
fn Decryptor::decrypt(
  self : Decryptor,
  _id : ObjectIdentifier,
  data : BytesView,
  _target : DecryptionTarget,
) -> Bytes? {
  match self {
    NoDecryptor => Some(data.to_bytes())
  }
}

///|
fn get_crypt_decryptor(
  dict : Dict,
  _id : Bytes,
  _password : Bytes,
) -> Result[Decryptor, DecryptionError] {
  let filter : Name? = dict.get("Filter")
  guard filter is Some(filter) else { Err(InvalidEncryption) }
  if filter.0 != "Standard" {
    return Err(UnsupportedAlgorithm)
  }
  let encryption_v : Byte? = dict.get("V")
  guard encryption_v is Some(_) else { Err(InvalidEncryption) }
  let revision : Byte? = dict.get("R")
  guard revision is Some(_) else { Err(InvalidEncryption) }
  Err(UnsupportedAlgorithm)
}
