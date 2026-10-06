// Port of `hayro-syntax/src/crypto/mod.rs`.
//
// Cryptographic implementations for hayro, ported from pdf.js.
//
// **Important note**: Please keep in mind that these haven't been
// audited and should not be used for security-critical purposes, like creating new
// encrypted PDFs. They solely serve the purpose of being able to decrypt and read
// _already_ encrypted documents, where security isn't really relevant.
//
// The submodules live in `crypto_aes.mbt`, `crypto_md5.mbt`, `crypto_rc4.mbt`,
// `crypto_sha256.mbt`, `crypto_sha384.mbt` and `crypto_sha512.mbt`.

///|
let password_padding : Bytes = b"\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A"

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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecryptionError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecryptionError with @debug.Debug::{to_repr}

///|
priv enum DecryptorTag {
  /// Upstream `DecryptorTag::None` (renamed so it does not shadow
  /// `Option::None`).
  NoneTag
  Rc4
  Aes128
  Aes256
} derive(Eq)

///|
fn DecryptorTag::from_name(name : Name) -> DecryptorTag? {
  match name.as_str() {
    "None" | "Identity" => Some(NoneTag)
    "V2" => Some(DecryptorTag::Rc4)
    "AESV2" => Some(DecryptorTag::Aes128)
    "AESV3" => Some(DecryptorTag::Aes256)
    _ => None
  }
}

///|
priv enum Decryptor {
  /// Upstream `Decryptor::None`.
  NoDecryptor
  Rc4(key~ : Bytes)
  Aes128(key~ : Bytes, dict~ : DecryptorData)
  Aes256(key~ : Bytes, dict~ : DecryptorData)
}

///|
pub(all) enum DecryptionTarget {
  String
  Stream
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecryptionTarget with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecryptionTarget with @debug.Debug::{to_repr}

///|
fn Decryptor::decrypt(
  self : Decryptor,
  id : ObjectIdentifier,
  data : BytesView,
  target : DecryptionTarget,
) -> Bytes? {
  match self {
    NoDecryptor => Some(data.to_owned())
    Decryptor::Rc4(key~) => decrypt_rc4(key, data, id)
    Decryptor::Aes128(key~, dict~) | Decryptor::Aes256(key~, dict~) => {
      let crypt_dict = match target {
        String => dict.string_filter
        Stream => dict.stream_filter
      }
      match crypt_dict.cfm {
        NoneTag => Some(data.to_owned())
        DecryptorTag::Rc4 => decrypt_rc4(key, data, id)
        DecryptorTag::Aes128 => decrypt_aes128(key, data, id)
        DecryptorTag::Aes256 => decrypt_aes256(key, data)
      }
    }
  }
}

///|
/// Upstream `crypto::get`.
fn get_crypt_decryptor(
  dict : Dict,
  id : Bytes,
  password : Bytes,
) -> Result[Decryptor, DecryptionError] {
  let filter : Name? = dict.get("Filter")
  guard filter is Some(filter) else { Err(InvalidEncryption) }
  if filter.as_bytes() != b"Standard" {
    return Err(UnsupportedAlgorithm)
  }
  let encryption_v : Byte? = dict.get("V")
  guard encryption_v is Some(encryption_v) else { Err(InvalidEncryption) }
  let encryption_v = encryption_v.to_int()
  let encrypt_metadata = (dict.get("EncryptMetadata") : Bool?).unwrap_or(true)
  let revision : Byte? = dict.get("R")
  guard revision is Some(revision) else { Err(InvalidEncryption) }
  let revision = revision.to_int()
  let length = match encryption_v {
    1 => 40
    2 => (dict.get("Length") : UInt16?).map(l => l.to_int()).unwrap_or(40)
    4 => (dict.get("Length") : UInt16?).map(l => l.to_int()).unwrap_or(128)
    5 => 256
    _ => return Err(UnsupportedAlgorithm)
  }
  let (algorithm, data) : (DecryptorTag, DecryptorData?) = match encryption_v {
    1 => (DecryptorTag::Rc4, None)
    2 => (DecryptorTag::Rc4, None)
    4 => {
      guard DecryptorData::from_dict(dict, length) is Some(data) else {
        return Err(InvalidEncryption)
      }
      (DecryptorTag::Aes128, Some(data))
    }
    5 | 6 => {
      guard DecryptorData::from_dict(dict, length) is Some(data) else {
        return Err(InvalidEncryption)
      }
      (DecryptorTag::Aes256, Some(data))
    }
    _ => return Err(UnsupportedAlgorithm)
  }
  let byte_length = length / 8
  if byte_length == 0 {
    return Err(InvalidEncryption)
  }
  let owner_string : PdfString? = dict.get("O")
  guard owner_string is Some(owner_string) else { Err(InvalidEncryption) }
  let user_string : PdfString? = dict.get("U")
  guard user_string is Some(user_string) else { Err(InvalidEncryption) }
  let permissions = {
    let raw : Int64? = dict.get("P")
    guard raw is Some(raw) else { return Err(InvalidEncryption) }
    // Both branches upstream (`raw < 0` via `i32`, else `raw as u32`) keep
    // the low 32 bits.
    raw.to_int().reinterpret_as_uint()
  }
  let mut decryption_key = if revision <= 4 {
    let key = match
      decryption_key_rev1234(
        password, encrypt_metadata, revision, byte_length, owner_string, permissions,
        id,
      ) {
      Ok(key) => key
      Err(e) => return Err(e)
    }
    match authenticate_user_password_rev234(revision, key, id, user_string) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
    key
  } else {
    match
      decryption_key_rev56(dict, revision, password, owner_string, user_string) {
      Ok(key) => key
      Err(e) => return Err(e)
    }
  }

  // See pdf.js issue 19484.
  if encryption_v == 4 && decryption_key.length() < 16 {
    decryption_key = resize_bytes(decryption_key, 16)
  }
  match algorithm {
    NoneTag => Ok(NoDecryptor)
    DecryptorTag::Rc4 => Ok(Decryptor::Rc4(key=decryption_key))
    DecryptorTag::Aes128 =>
      Ok(Decryptor::Aes128(key=decryption_key, dict=data.unwrap()))
    DecryptorTag::Aes256 =>
      Ok(Decryptor::Aes256(key=decryption_key, dict=data.unwrap()))
  }
}

///|
/// Algorithm 1.A: Encryption of data using the AES algorithms
fn decrypt_aes256(key : Bytes, data : BytesView) -> Bytes? {
  // a) Use the 32-byte file encryption key for the AES-256 symmetric key algorithm,
  // along with the string or stream data to be encrypted.
  // Use the AES algorithm in Cipher Block Chaining (CBC) mode, which requires an initialization
  // vector. The block size parameter is set to 16 bytes, and the initialization
  // vector is a 16-byte random number that is stored as the first 16 bytes of the
  // encrypted stream or string.
  guard data.length() >= 16 else { return None }
  let iv = data[:16]
  let data = data[16:]
  guard AESCipher::new_aes256(key[:]) is Some(cipher) else { return None }
  Some(cipher.decrypt_cbc(data, iv, true))
}

///|
fn decrypt_aes128(
  key : Bytes,
  data : BytesView,
  id : ObjectIdentifier,
) -> Bytes? {
  decrypt_rc_aes(key, id, true, key => {
    // If using the AES algorithm, the Cipher Block Chaining (CBC) mode, which requires an initialization
    // vector, is used. The block size parameter is set to 16 bytes, and the initialization vector is a 16-byte
    // random number that is stored as the first 16 bytes of the encrypted stream or string.
    guard AESCipher::new_aes128(key) is Some(cipher) else { return None }
    guard data.length() >= 16 else { return None }
    let iv = data[:16]
    let data = data[16:]
    Some(cipher.decrypt_cbc(data, iv, true))
  })
}

///|
fn decrypt_rc4(key : Bytes, data : BytesView, id : ObjectIdentifier) -> Bytes? {
  decrypt_rc_aes(key, id, false, key => {
    let rc = Rc4::new(key)
    Some(rc.decrypt(data))
  })
}

///|
/// Algorithm 1: Encryption of data using the RC4 or AES algorithms
fn decrypt_rc_aes(
  key : Bytes,
  id : ObjectIdentifier,
  aes : Bool,
  with_key : (BytesView) -> Bytes?,
) -> Bytes? {
  let n = key.length()
  // a) Obtain the object number and generation number from the object identifier of
  // the string or stream to be encrypted (see 7.3.10, "Indirect objects"). If the
  // string is a direct object, use the identifier of the indirect object containing
  // it.
  let key_buf : Array[Byte] = Array(capacity=n + 9)
  for b in key {
    key_buf.push(b)
  }

  // b) For all strings and streams without crypt filter specifier; treating the
  // object number and generation number as binary integers, extend the original
  // n-byte file encryption key to n + 5 bytes by appending the low-order 3 bytes of
  // the object number and the low-order 2 bytes of the generation number in that
  // order, low-order byte first.
  let obj_number = id.obj_number
  key_buf.push(obj_number.to_byte())
  key_buf.push((obj_number >> 8).to_byte())
  key_buf.push((obj_number >> 16).to_byte())
  let gen_number = id.gen_number
  key_buf.push(gen_number.to_byte())
  key_buf.push((gen_number >> 8).to_byte())

  // If using the AES algorithm, extend the file encryption key an additional 4 bytes by adding the value
  // "sAlT", which corresponds to the hexadecimal values 0x73, 0x41, 0x6C, 0x54. (This addition is done
  // for backward compatibility and is not intended to provide additional security.)
  if aes {
    for b in b"sAlT" {
      key_buf.push(b)
    }
  }

  // c) Initialise the MD5 hash function and pass the result of step (b) as input
  // to this function.
  let hash = md5_calculate(Bytes::from_array(key_buf[:])[:])

  // d) Use the first (n + 5) bytes, up to a maximum of 16, of the output
  // from the MD5 hash as the key for the RC4 or AES symmetric key algorithms,
  // along with the string or stream data to be encrypted.
  let final_key = hash[:@cmp.minimum(16, n + 5)]
  with_key(final_key)
}

///|
priv struct DecryptorData {
  stream_filter : CryptDictionary
  string_filter : CryptDictionary
}

///|
fn DecryptorData::from_dict(
  dict : Dict,
  default_length : Int,
) -> DecryptorData? {
  let mappings : Map[String, CryptDictionary] = Map([])
  if (dict.get("CF") : Dict?) is Some(dict) {
    for key in dict.keys() {
      if (dict.get(key.0) : Dict?) is Some(dict) &&
        CryptDictionary::from_dict(dict, default_length) is Some(crypt_dict) {
        mappings[key.as_str()] = crypt_dict
      }
    }
  }
  guard (dict.get("StmF") : Name?) is Some(stm_f_name) else { return None }
  let stm_f = mappings
    .get(stm_f_name.as_str())
    .unwrap_or(CryptDictionary::identity(default_length))
  guard (dict.get("StrF") : Name?) is Some(str_f_name) else { return None }
  let str_f = mappings
    .get(str_f_name.as_str())
    .unwrap_or(CryptDictionary::identity(default_length))
  Some({ stream_filter: stm_f, string_filter: str_f, })
}

///|
priv struct CryptDictionary {
  cfm : DecryptorTag
  _length : Int
}

///|
fn CryptDictionary::from_dict(
  dict : Dict,
  default_length : Int,
) -> CryptDictionary? {
  guard (dict.get("CFM") : Name?) is Some(cfm_name) else { return None }
  guard DecryptorTag::from_name(cfm_name) is Some(cfm) else { return None }
  // The standard security handler expresses the Length entry in bytes (e.g., 32 means a
  // length of 256 bits) and public-key security handlers express it as is (e.g., 256 means a
  // length of 256 bits).
  // Note: We only support the standard security handler.
  let mut length = (dict.get("Length") : UInt16?)
    .map(l => l.to_int())
    .unwrap_or(default_length / 8)

  // When CFM is AESV2, the Length key shall have the value of 128. When
  // CFM is AESV3, the Length key shall have a value of 256.
  if cfm == DecryptorTag::Aes128 {
    length = 16
  } else if cfm == DecryptorTag::Aes256 {
    length = 32
  }
  Some({ cfm, _length: length, })
}

///|
fn CryptDictionary::identity(default_length : Int) -> CryptDictionary {
  { cfm: NoneTag, _length: default_length, }
}

///|
/// Algorithm 2.B: Computing a hash (revision 6 and later)
fn compute_hash_rev56(
  password : BytesView,
  validation_salt : BytesView,
  user_string : BytesView?,
  revision : Int,
) -> Result[Bytes, DecryptionError] {
  // Take the SHA-256 hash of the original input to the algorithm and name the resulting
  // 32 bytes, K.
  let mut k = {
    let input = Buffer()
    input.write_bytesview(password)
    input.write_bytesview(validation_salt)
    if user_string is Some(user_string) {
      input.write_bytesview(user_string)
    }
    let hash = sha256_calculate(input.contents()[:])

    // Apparently revision 5 only uses this hash.
    if revision == 5 {
      return Ok(hash)
    }
    hash
  }
  let mut round = 0

  // Perform the following steps (a)-(d) 64 times:
  while true {
    // a) Make a new string, K1, consisting of 64 repetitions of the sequence:
    // input password, K, the 48-byte user key. The 48 byte user key is only used when
    // checking the owner password or creating the owner key. If checking the user
    // password or creating the user key, K1 is the concatenation of the input
    // password and K.
    let k1 = {
      let single = Buffer()
      single.write_bytesview(password)
      single.write_bytes(k)
      if user_string is Some(user_string) {
        single.write_bytesview(user_string)
      }
      let single = single.contents()
      let repeated = Buffer(size_hint=single.length() * 64)
      for _ in 0..<64 {
        repeated.write_bytes(single)
      }
      repeated.contents()
    }

    // b) Encrypt K1 with the AES-128 (CBC, no padding) algorithm,
    // using the first 16 bytes of K as the key and the second 16 bytes of K as the
    // initialization vector. The result of this encryption is E.
    let e = {
      guard AESCipher::new_aes128(k[:16]) is Some(aes) else {
        return Err(InvalidEncryption)
      }
      let res = aes.encrypt_cbc(k1[:], k[16:32])

      // Remove padding that was added by `encrypt_cbc`.
      res[:k1.length()]
    }

    // c) Taking the first 16 bytes of E as an unsigned big-endian integer,
    // compute the remainder, modulo 3. If the result is 0, the next hash used is
    // SHA-256, if the result is 1, the next hash used is SHA-384, if the result is
    // 2, the next hash used is SHA-512.
    let mut num = 0
    for i in 0..<16 {
      num = (num * 256 + e[i].to_int()) % 3
    }

    // d) Using the hash algorithm determined in step c, take the hash of E.
    // The result is a new value of K, which will be 32, 48, or 64 bytes in length.
    k = match num {
      0 => sha256_calculate(e)
      1 => sha384_calculate(e)
      2 => sha512_calculate(e)
      _ => abort("unreachable")
    }
    round += 1

    // Repeat the process (a-d) with this new value for K. Following 64 rounds
    // (round number 0 to round number 63), do the following, starting with round
    // number 64:
    if round > 63 {
      // e) Look at the very last byte of E. If the value of that byte
      // (taken as an unsigned integer) is greater than the round number - 32,
      // repeat steps (a-d) again.
      let last_byte = e[e.length() - 1]

      // f) Repeat from steps (a-e) until the value of the last byte
      // is < (round number) - 32.
      // For some reason we need to use <= here?
      if last_byte.to_int() <= round - 32 {
        break
      }
    }
  }

  // The first 32 bytes of the final K are the output of the algorithm.
  Ok(k[:32].to_owned())
}

///|
/// Algorithm 2: Computing a file encryption key in order to encrypt a document (revision 4 and earlier)
fn decryption_key_rev1234(
  password : Bytes,
  encrypt_metadata : Bool,
  revision : Int,
  byte_length : Int,
  owner_string : PdfString,
  permissions : UInt,
  id : Bytes,
) -> Result[Bytes, DecryptionError] {
  let md5_input = Buffer()

  // TODO: Convert to PDFDocEncoding.
  // a) Pad or truncate password to 32 bytes using PASSWORD_PADDING.
  let copy_len = @cmp.minimum(password.length(), 32)
  let padded_password = Buffer(size_hint=32)
  padded_password.write_bytesview(password[:copy_len])
  if copy_len < 32 {
    padded_password.write_bytesview(password_padding[:32 - copy_len])
  }

  // b) Initialise the MD5 hash function and pass the
  // result of step a) as input to this function.
  md5_input.write_bytes(padded_password.contents())

  // c) Pass the value of the encryption dictionary's O entry
  // to the MD5 hash function.
  md5_input.write_bytes(owner_string.as_bytes())

  // d) Convert the integer value of the P entry to a 32-bit unsigned
  // binary number and pass these bytes to the MD5 hash function, low-order byte first.
  md5_input.write_uint_le(permissions)

  // e) Pass the first element of the file's file identifier array to the MD5 hash function.
  md5_input.write_bytes(id)

  // f) (Security handlers of revision 4 or greater) If document metadata
  // is not being encrypted, pass 4 bytes with the value 0xFFFFFFFF to the MD5 hash function.
  if !encrypt_metadata && revision >= 4 {
    md5_input.write_bytes(b"\xff\xff\xff\xff")
  }

  // g) Finish the hash.
  let mut hash = md5_calculate(md5_input.contents()[:])
  if byte_length > hash.length() {
    return Err(InvalidEncryption)
  }

  // h) For revisions >= 3, do the following 50 times: Take the output from the previous
  // MD5 hash and pass the first n bytes of the output as input into a new MD5 hash,
  // where n is the number of bytes of the file encryption key as defined by the value
  // of the encryption dictionary's `Length` entry.
  if revision >= 3 {
    for _ in 0..<50 {
      hash = md5_calculate(hash[:byte_length])
    }
  }
  let decryption_key = hash[:byte_length].to_owned()
  Ok(decryption_key)
}

///|
/// Algorithm 6: Authenticating the user password
fn authenticate_user_password_rev234(
  revision : Int,
  decryption_key : Bytes,
  id : Bytes,
  user_string : PdfString,
) -> Result[Unit, DecryptionError] {
  // a) Perform all but the last step of Algorithm 4 (revision 2) or Algorithm 5 (revision 3 + 4).
  let result = match revision {
    2 => user_password_rev2(decryption_key)
    3 | 4 => user_password_rev34(decryption_key, id)
    _ => return Err(InvalidEncryption)
  }

  // b) If the result of step (a) is equal to the value of the encryption dictionary's
  // U entry (comparing on the first 16 bytes in the case of security handlers of
  // revision 3 or greater), the password supplied is the correct user password.
  let user_string = user_string.as_bytes()
  match revision {
    2 => if result != user_string { return Err(PasswordProtected) }
    3 | 4 =>
      if user_string.length() < 16 ||
        result[:16].to_owned() != user_string[:16].to_owned() {
        return Err(PasswordProtected)
      }
    _ => abort("unreachable")
  }
  Ok(())
}

///|
/// Algorithm 4: Computing the encryption dictionary’s U-entry value
/// (Security handlers of revision 2).
fn user_password_rev2(decryption_key : Bytes) -> Bytes {
  // a) Create a file encryption key based on the user password string.
  // b) Encrypt the 32-byte padding string using an RC4 encryption
  // function with the file encryption key from the preceding step.
  let rc = Rc4::new(decryption_key[:])
  rc.decrypt(password_padding[:])
}

///|
/// Algorithm 5: Computing the encryption dictionary’s U (user password)
/// value (Security handlers of revision 3 or 4).
fn user_password_rev34(decryption_key : Bytes, id : Bytes) -> Bytes {
  // a) Create a file encryption key based on the user password string.
  let rc = Rc4::new(decryption_key[:])
  let input = Buffer()
  // b) Initialise the MD5 hash function and pass the 32-byte padding string.
  input.write_bytes(password_padding)

  // c) Pass the first element of the file's file identifier array to the hash function
  // and finish the hash.
  input.write_bytes(id)
  let hash = md5_calculate(input.contents()[:])

  // d) Encrypt the 16-byte result of the hash, using an RC4 encryption function with
  // the encryption key from step (a).
  let mut encrypted = rc.encrypt(hash[:])

  // e) Do the following 19 times: Take the output from the previous invocation of the
  // RC4 function and pass it as input to a new invocation of the function; use a file
  // encryption key generated by taking each byte of the original file encryption key
  // obtained in step (a) and performing an XOR (exclusive or) operation between that
  // byte and the single-byte value of the iteration counter (from 1 to 19).
  for i in 1..<=19 {
    let key = Bytes::makei(decryption_key.length(), j => {
      decryption_key[j] ^ i.to_byte()
    })
    let rc = Rc4::new(key[:])
    encrypted = rc.encrypt(encrypted[:])
  }
  resize_bytes(encrypted, 32)
}

///|
/// Algorithm 2.A: Retrieving the file encryption key from an encrypted document in order to decrypt it (revision 6 and later)
fn decryption_key_rev56(
  dict : Dict,
  revision : Int,
  password : Bytes,
  owner_string : PdfString,
  user_string : PdfString,
) -> Result[Bytes, DecryptionError] {
  // a) The UTF-8 password string shall be generated from Unicode input by processing the input string with
  // the SASLprep (Internet RFC 4013) profile of stringprep (Internet RFC 3454) using the Normalize and BiDi
  // options, and then converting to a UTF-8 representation.
  // TODO: Do the above.
  // b) Truncate the UTF-8 representation to 127 bytes if it is longer than 127 bytes.
  let password = password[:@cmp.minimum(password.length(), 127)]
  let string_len = if revision <= 4 { 32 } else { 48 }
  let owner_string = owner_string.as_bytes()
  guard owner_string.length() >= string_len else {
    return Err(InvalidEncryption)
  }
  let trimmed_os = owner_string[:string_len]
  guard trimmed_os.length() >= 32 else { return Err(InvalidEncryption) }
  let owner_hash = trimmed_os[:32]
  let owner_tail = trimmed_os[32:]
  guard owner_tail.length() >= 8 else { return Err(InvalidEncryption) }
  let owner_validation_salt = owner_tail[:8]
  let owner_key_salt = owner_tail[8:]
  let user_string = user_string.as_bytes()
  guard user_string.length() >= string_len else {
    return Err(InvalidEncryption)
  }
  let trimmed_us = user_string[:string_len]
  guard trimmed_us.length() >= 32 else { return Err(InvalidEncryption) }
  let user_hash = trimmed_us[:32]
  let user_tail = trimmed_us[32:]
  guard user_tail.length() >= 8 else { return Err(InvalidEncryption) }
  let user_validation_salt = user_tail[:8]
  let user_key_salt = user_tail[8:]

  // c) Test the password against the owner key by computing a hash using algorithm 2.B
  // with an input string consisting of the UTF-8 password concatenated with the 8 bytes of
  // owner Validation Salt, concatenated with the 48-byte U string. If the 32-byte result
  // matches the first 32 bytes of the O string, this is the owner password.
  let owner_check = match
    compute_hash_rev56(
      password,
      owner_validation_salt,
      Some(trimmed_us),
      revision,
    ) {
    Ok(h) => h
    Err(e) => return Err(e)
  }
  if owner_check == owner_hash.to_owned() {
    // d) Compute an intermediate owner key by computing a hash using algorithm 2.B with an input string
    // consisting of the UTF-8 owner password concatenated with the 8 bytes of owner Key Salt,
    // concatenated with the 48-byte U string. The 32-byte result is the key used to decrypt the 32-byte OE string
    // using AES-256 in CBC mode with no padding and an initialization vector of zero. The 32-byte result is the file encryption key.
    let intermediate_owner_key = match
      compute_hash_rev56(password, owner_key_salt, Some(trimmed_us), revision) {
      Ok(h) => h
      Err(e) => return Err(e)
    }
    let oe_string : PdfString? = dict.get("OE")
    guard oe_string is Some(oe_string) else { return Err(InvalidEncryption) }
    if oe_string.as_bytes().length() != 32 {
      return Err(InvalidEncryption)
    }
    guard AESCipher::new_aes256(intermediate_owner_key[:]) is Some(cipher) else {
      return Err(InvalidEncryption)
    }
    let zero_iv : Bytes = Bytes::make(16, 0)
    return Ok(cipher.decrypt_cbc(oe_string.as_bytes()[:], zero_iv[:], false))
  }
  let user_check = match
    compute_hash_rev56(password, user_validation_salt, None, revision) {
    Ok(h) => h
    Err(e) => return Err(e)
  }
  if user_check == user_hash.to_owned() {
    // e) Compute an intermediate user key by computing a hash using algorithm 2.B with an input string
    // consisting of the UTF-8 user password concatenated with the 8 bytes of user Key Salt. The 32-byte result
    // is the key used to decrypt the 32-byte UE string using AES-256 in CBC mode with no padding and an
    // initialization vector of zero. The 32-byte result is the file encryption key.
    let intermediate_key = match
      compute_hash_rev56(password, user_key_salt, None, revision) {
      Ok(h) => h
      Err(e) => return Err(e)
    }
    let ue_string : PdfString? = dict.get("UE")
    guard ue_string is Some(ue_string) else { return Err(InvalidEncryption) }
    if ue_string.as_bytes().length() != 32 {
      return Err(InvalidEncryption)
    }
    guard AESCipher::new_aes256(intermediate_key[:]) is Some(cipher) else {
      return Err(InvalidEncryption)
    }
    let zero_iv : Bytes = Bytes::make(16, 0)
    Ok(cipher.decrypt_cbc(ue_string.as_bytes()[:], zero_iv[:], false))
  } else {
    Err(PasswordProtected)
  }

  // TODO:
  // f) Decrypt the 16-byte Perms string using AES-256 in ECB mode with an initialization vector of zero and
  // the file encryption key as the key. Verify that bytes 9-11 of the result are the characters "a", "d",
  // "b". Bytes 0-3 of the decrypted Perms entry, treated as a little-endian integer, are the user
  // permissions. They shall match the value in the P key.
}

///|
/// `Vec::resize(n, 0)`.
fn resize_bytes(data : Bytes, n : Int) -> Bytes {
  Bytes::makei(n, i => if i < data.length() { data[i] } else { 0 })
}
