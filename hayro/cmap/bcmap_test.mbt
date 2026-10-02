// Ports of the `bcmap_tests` of `hayro-cmap/src/lib.rs` (which upstream run
// with the `embed-cmaps` feature).
//
// The bundle is not embedded (Typst does not enable `embed-cmaps`), so these
// tests read the decompressed bundle from `target/hayro-cmaps.bundle`, which
// can be created with
//   brotli -d -c target/hayro/hayro-cmap/assets/cmaps.brotli > target/hayro-cmaps.bundle
// and are skipped when it is missing.

///|
fn load_bundle() -> @cmap.Bundle? {
  guard module_root() is Some(root) else { return None }
  for path in ["target/hayro-cmaps.bundle", "target/scratch/cmaps.bundle"] {
    if @fs.path_exists(root + path) {
      let data = @fs.read_file_to_bytes(root + path) catch { _ => return None }
      return @cmap.Bundle::new(data)
    }
  }
  None
}

///|
fn embedded(bundle : @cmap.Bundle, name : @cmap.CMapName) -> @cmap.CMap {
  let data = bundle.load_embedded(name).unwrap()
  @cmap.CMap::parse_with_bundle(data, n => bundle.load_embedded(n), bundle).unwrap()
}

///|
test "embedded cmaps" {
  guard load_bundle() is Some(bundle) else { return }

  // embedded_h_cmap
  let cmap = embedded(bundle, H)
  assert_eq(cmap.metadata().writing_mode, None)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeJapan1, supplement: 1, }),
  )
  assert_eq(cmap.lookup_cid_code(0x2121, 2), Some(633))
  assert_eq(cmap.lookup_cid_code(0x2221, 2), Some(727))

  // embedded_90ms_rksj_h
  let cmap = embedded(bundle, N90msRksjH)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeJapan1, supplement: 2, }),
  )
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(231))
  assert_eq(cmap.lookup_cid_code(0x8140, 2), Some(633))

  // embedded_v_cmap
  let cmap = embedded(bundle, V)
  assert_eq(cmap.metadata().writing_mode, Some(Vertical))
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeJapan1, supplement: 1, }),
  )
  // Inherited from base "H" via usecmap.
  assert_eq(cmap.lookup_cid_code(0x2121, 2), Some(633))

  // embedded_gbk_euc_h
  let cmap = embedded(bundle, GbkEucH)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeGB1, supplement: 2, }),
  )
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(7716))
  assert_eq(cmap.lookup_cid_code(0x21, 1), Some(814))
  assert_eq(cmap.lookup_cid_code(0x7E, 1), Some(814 + 0x7E - 0x21))
  assert_eq(cmap.lookup_cid_code(0xFE80, 2), Some(22094))
  assert_eq(cmap.lookup_cid_code(0xFEA0, 2), Some(22094 + 0xA0 - 0x80))

  // embedded_ksc_euc_h
  let cmap = embedded(bundle, KscEucH)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeKorea1, supplement: 0, }),
  )
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(8094))
  assert_eq(cmap.lookup_cid_code(0x41, 1), Some(8094 + 0x41 - 0x20))
  assert_eq(cmap.lookup_cid_code(0xA1A1, 2), Some(101))
  assert_eq(cmap.lookup_cid_code(0xA1FE, 2), Some(101 + 0xFE - 0xA1))
  assert_eq(cmap.lookup_cid_code(0xFDA1, 2), Some(7962))

  // embedded_b5pc_h
  let cmap = embedded(bundle, B5pcH)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeCNS1, supplement: 0, }),
  )
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(1))
  assert_eq(cmap.lookup_cid_code(0x41, 1), Some(1 + 0x41 - 0x20))
  assert_eq(cmap.lookup_cid_code(0x80, 1), Some(61))
  assert_eq(cmap.lookup_cid_code(0xD140, 2), Some(7251))
  assert_eq(cmap.lookup_cid_code(0xD17E, 2), Some(7251 + 0x7E - 0x40))
  assert_eq(cmap.lookup_cid_code(0xF9D5, 2), Some(13642 + 3))

  // embedded_unijis_utf16_h
  let cmap = embedded(bundle, UniJisUtf16H)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeJapan1, supplement: 7, }),
  )
  assert_eq(cmap.lookup_cid_code(0x20, 2), Some(1))
  assert_eq(cmap.lookup_cid_code(0x41, 2), Some(1 + 0x41 - 0x20))
  assert_eq(cmap.lookup_cid_code(0x5C, 2), Some(97))
  assert_eq(cmap.lookup_cid_code(0x5BCC, 2), Some(3531))
  assert_eq(cmap.lookup_cid_code(0xD884DF50, 4), Some(19130))

  // embedded_identity_h
  let cmap = embedded(bundle, IdentityH)
  assert_eq(cmap.metadata().writing_mode, None)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeIdentity, supplement: 0, }),
  )
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(0))
  assert_eq(cmap.lookup_cid_code(0x0041, 2), Some(0x41))
  assert_eq(cmap.lookup_cid_code(0xFFFF, 2), Some(0xFFFF))

  // embedded_identity_v
  let cmap = embedded(bundle, IdentityV)
  assert_eq(cmap.metadata().writing_mode, Some(Vertical))
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeIdentity, supplement: 0, }),
  )
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(0))
  assert_eq(cmap.lookup_cid_code(0x0041, 2), Some(0x41))
  assert_eq(cmap.lookup_cid_code(0xFFFF, 2), Some(0xFFFF))

  // embedded_adobe_gb1_ucs2
  let cmap = embedded(bundle, AdobeGb1Ucs2)
  assert_eq(
    cmap.metadata().character_collection,
    Some({
      family: Custom(registry=b"Adobe", ordering=b"Adobe_GB1_UCS2"),
      supplement: 5,
    }),
  )
  assert_eq(cmap.lookup_bf_string(0x0063), Some(Char('\u{00B7}')))
  assert_eq(cmap.lookup_bf_string(0x0001), Some(Char(' ')))
  assert_eq(cmap.lookup_bf_string(0x0022), Some(Char('A')))
  assert_eq(cmap.lookup_bf_string(0x005F), Some(Char('~')))
  assert_eq(cmap.lookup_bf_string(0x560F), Some(String("\u{90CE}\u{FE00}")))

  // embedded_adobe_japan1_ucs2
  let cmap = embedded(bundle, AdobeJapan1Ucs2)
  assert_eq(
    cmap.metadata().character_collection,
    Some({
      family: Custom(registry=b"Adobe", ordering=b"Adobe_Japan1_UCS2"),
      supplement: 7,
    }),
  )
  assert_eq(cmap.lookup_bf_string(0x003D), Some(Char('\u{00A5}')))
  assert_eq(cmap.lookup_bf_string(0x0001), Some(Char(' ')))
  assert_eq(cmap.lookup_bf_string(0x003C), Some(Char('[')))
  assert_eq(cmap.lookup_bf_string(0x0476), Some(String("\u{82A6}\u{E0100}")))
  assert_eq(cmap.lookup_bf_string(0x265B), Some(String("10/11")))
  assert_eq(
    cmap.lookup_bf_string(0x2E6B),
    Some(String("オングストローム")),
  )

  // embedded_adobe_korea1_ucs2
  let cmap = embedded(bundle, AdobeKorea1Ucs2)
  assert_eq(
    cmap.metadata().character_collection,
    Some({
      family: Custom(registry=b"Adobe", ordering=b"Adobe_Korea1_UCS2"),
      supplement: 2,
    }),
  )
  assert_eq(cmap.lookup_bf_string(0x0060), Some(Char('\u{20A9}')))
  assert_eq(cmap.lookup_bf_string(0x2072), Some(String("[10]")))
  assert_eq(cmap.lookup_bf_string(0x2073), Some(String("[11]")))

  // embedded_adobe_cns1_ucs2
  let cmap = embedded(bundle, AdobeCns1Ucs2)
  assert_eq(
    cmap.metadata().character_collection,
    Some({
      family: Custom(registry=b"Adobe", ordering=b"Adobe_CNS1_UCS2"),
      supplement: 7,
    }),
  )
  assert_eq(cmap.lookup_bf_string(0x0060), Some(Char('\u{00A9}')))
  assert_eq(cmap.lookup_bf_string(0x0001), Some(Char(' ')))
  assert_eq(cmap.lookup_bf_string(0x005F), Some(Char('~')))
  assert_eq(cmap.lookup_bf_string(0x36B0), Some(Char('\u{200CC}')))

  // embedded_eten_b5_h
  let cmap = embedded(bundle, ETenB5H)
  assert_eq(
    cmap.metadata().character_collection,
    Some({ family: AdobeCNS1, supplement: 0, }),
  )
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(13648))
  assert_eq(cmap.lookup_cid_code(0x7E, 1), Some(13648 + 0x7E - 0x20))
  assert_eq(cmap.lookup_cid_code(0xA140, 2), Some(99))
  assert_eq(cmap.lookup_cid_code(0xA158, 2), Some(99 + 0x58 - 0x40))
  assert_eq(cmap.lookup_cid_code(0xD040, 2), Some(7094))
  assert_eq(cmap.lookup_cid_code(0xF9FE, 2), Some(14056 + 0xFE - 0xD6))

  // All 65 embedded cmaps parse.
  let names = [
    "83pv-RKSJ-H", "90ms-RKSJ-H", "90ms-RKSJ-V", "90msp-RKSJ-H", "90msp-RKSJ-V",
    "90pv-RKSJ-H", "Add-RKSJ-H", "Add-RKSJ-V", "Adobe-CNS1-UCS2", "Adobe-GB1-UCS2",
    "Adobe-Japan1-UCS2", "Adobe-Korea1-UCS2", "B5pc-H", "B5pc-V", "CNS-EUC-H", "CNS-EUC-V",
    "ETen-B5-H", "ETen-B5-V", "ETenms-B5-H", "ETenms-B5-V", "EUC-H", "EUC-V", "Ext-RKSJ-H",
    "Ext-RKSJ-V", "GB-EUC-H", "GB-EUC-V", "GBK-EUC-H", "GBK-EUC-V", "GBK2K-H", "GBK2K-V",
    "GBKp-EUC-H", "GBKp-EUC-V", "GBpc-EUC-H", "GBpc-EUC-V", "H", "HKscs-B5-H", "HKscs-B5-V",
    "Identity-H", "Identity-V", "KSC-EUC-H", "KSC-EUC-V", "KSCms-UHC-H", "KSCms-UHC-HW-H",
    "KSCms-UHC-HW-V", "KSCms-UHC-V", "KSCpc-EUC-H", "UniCNS-UCS2-H", "UniCNS-UCS2-V",
    "UniCNS-UTF16-H", "UniCNS-UTF16-V", "UniGB-UCS2-H", "UniGB-UCS2-V", "UniGB-UTF16-H",
    "UniGB-UTF16-V", "UniJIS-UCS2-H", "UniJIS-UCS2-HW-H", "UniJIS-UCS2-HW-V", "UniJIS-UCS2-V",
    "UniJIS-UTF16-H", "UniJIS-UTF16-V", "UniKS-UCS2-H", "UniKS-UCS2-V", "UniKS-UTF16-H",
    "UniKS-UTF16-V", "V",
  ]
  for n in names {
    let name = @cmap.CMapName::from_bytes(ascii_bytes(n))
    let cmap = embedded(bundle, name)
    // The embedded name is the cmap name itself.
    assert_eq(cmap.metadata().name, Some(ascii_bytes(n)))
  }
}
