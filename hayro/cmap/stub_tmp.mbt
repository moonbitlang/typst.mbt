// TEMPORARY stub of the hayro-cmap package (replaced by the real port).

///|
pub(all) enum CMapName {
  IdentityH
  IdentityV
  AdobeIdentityUcs2
  Other(Bytes)
} derive(Eq, Debug)

///|
pub fn CMapName::from_bytes(name : BytesView) -> CMapName {
  if name == b"Identity-H"[:] {
    IdentityH
  } else if name == b"Identity-V"[:] {
    IdentityV
  } else {
    Other(name.to_bytes())
  }
}

///|
pub(all) enum WritingMode {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
pub(all) enum CidFamily {
  AdobeIdentity
  Other
} derive(Eq, Debug)

///|
pub fn CidFamily::from_registry_ordering(
  _registry : BytesView,
  _ordering : BytesView,
) -> CidFamily {
  Other
}

///|
pub fn CidFamily::ucs2_cmap(_self : CidFamily) -> CMapName? {
  None
}

///|
pub(all) struct CharacterCollection {
  family : CidFamily
  supplement : Int
} derive(Eq, Debug)

///|
pub(all) struct Metadata {
  character_collection : CharacterCollection?
  name : Bytes?
  writing_mode : WritingMode?
}

///|
pub(all) enum BfString {
  Char(Char)
  String(String)
} derive(Eq, Debug)

///|
pub struct CMap {
  priv metadata : Metadata
}

///|
pub fn CMap::parse(
  _data : BytesView,
  _get_cmap : (CMapName) -> Bytes?,
) -> CMap? {
  None
}

///|
pub fn CMap::identity_h() -> CMap {
  {
    metadata: {
      character_collection: Some({ family: AdobeIdentity, supplement: 0, }),
      name: Some(b"Identity-H"),
      writing_mode: Some(Horizontal),
    },
  }
}

///|
pub fn CMap::identity_v() -> CMap {
  {
    metadata: {
      character_collection: Some({ family: AdobeIdentity, supplement: 0, }),
      name: Some(b"Identity-V"),
      writing_mode: Some(Vertical),
    },
  }
}

///|
pub fn CMap::metadata(self : CMap) -> Metadata {
  self.metadata
}

///|
pub fn CMap::lookup_cid_code(
  _self : CMap,
  code : UInt,
  byte_len : Int,
) -> UInt? {
  if byte_len == 2 && code <= 0xFFFF {
    Some(code)
  } else {
    None
  }
}

///|
pub fn CMap::lookup_bf_string(_self : CMap, _code : UInt) -> BfString? {
  None
}
