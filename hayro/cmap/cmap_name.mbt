// Port of the `CMapName` part of `hayro-cmap/src/lib.rs`.

///|
/// The name of the cmap.
pub(all) enum CMapName {
  // ── Adobe-Japan1 (Japanese) ── Shift-JIS (RKSJ) encodings ──
  /// `83pv-RKSJ-H` — Adobe-Japan1, Mac Shift-JIS (`KanjiTalk` 6), horizontal.
  N83pvRksjH
  /// `90ms-RKSJ-H` — Adobe-Japan1, Windows Shift-JIS (code page 932), horizontal.
  N90msRksjH
  /// `90ms-RKSJ-V` — Adobe-Japan1, Windows Shift-JIS (code page 932), vertical.
  N90msRksjV
  /// `90msp-RKSJ-H` — Adobe-Japan1, Windows Shift-JIS with proportional Roman, horizontal.
  N90mspRksjH
  /// `90msp-RKSJ-V` — Adobe-Japan1, Windows Shift-JIS with proportional Roman, vertical.
  N90mspRksjV
  /// `90pv-RKSJ-H` — Adobe-Japan1, Mac Shift-JIS (`KanjiTalk` 7), horizontal.
  N90pvRksjH
  /// `Add-RKSJ-H` — Adobe-Japan1, Fujitsu FMR Shift-JIS, horizontal.
  AddRksjH
  /// `Add-RKSJ-V` — Adobe-Japan1, Fujitsu FMR Shift-JIS, vertical.
  AddRksjV

  // ── Adobe UCS2 (CID → Unicode) ──
  // Note that these are not part of the predefined CMaps, but we use them
  // so we can more easily map CIDs back to Unicode.
  /// `Adobe-CNS1-UCS2` — Adobe-CNS1, CID-to-Unicode mapping.
  AdobeCns1Ucs2
  /// `Adobe-GB1-UCS2` — Adobe-GB1, CID-to-Unicode mapping.
  AdobeGb1Ucs2
  /// `Adobe-Japan1-UCS2` — Adobe-Japan1, CID-to-Unicode mapping.
  AdobeJapan1Ucs2
  /// `Adobe-Korea1-UCS2` — Adobe-Korea1, CID-to-Unicode mapping.
  AdobeKorea1Ucs2

  // ── Adobe-CNS1 (Traditional Chinese) ── Big Five encodings ──
  /// `B5pc-H` — Adobe-CNS1, Mac Big Five (`ETen` extensions), horizontal.
  B5pcH
  /// `B5pc-V` — Adobe-CNS1, Mac Big Five (`ETen` extensions), vertical.
  B5pcV
  /// `CNS-EUC-H` — Adobe-CNS1, CNS 11643 EUC encoding, horizontal.
  CnsEucH
  /// `CNS-EUC-V` — Adobe-CNS1, CNS 11643 EUC encoding, vertical.
  CnsEucV
  /// `ETen-B5-H` — Adobe-CNS1, `ETen` Big Five extensions, horizontal.
  ETenB5H
  /// `ETen-B5-V` — Adobe-CNS1, `ETen` Big Five extensions, vertical.
  ETenB5V
  /// `ETenms-B5-H` — Adobe-CNS1, `ETen` Big Five with Microsoft symbol extensions, horizontal.
  ETenmsB5H
  /// `ETenms-B5-V` — Adobe-CNS1, `ETen` Big Five with Microsoft symbol extensions, vertical.
  ETenmsB5V

  // ── Adobe-Japan1 (Japanese) ── EUC and extended Shift-JIS encodings ──
  /// `EUC-H` — Adobe-Japan1, JIS X 0208 EUC-JP encoding, horizontal.
  EucH
  /// `EUC-V` — Adobe-Japan1, JIS X 0208 EUC-JP encoding, vertical.
  EucV
  /// `Ext-RKSJ-H` — Adobe-Japan1, Shift-JIS with NEC/IBM extensions, horizontal.
  ExtRksjH
  /// `Ext-RKSJ-V` — Adobe-Japan1, Shift-JIS with NEC/IBM extensions, vertical.
  ExtRksjV

  // ── Adobe-GB1 (Simplified Chinese) ──
  /// `GB-EUC-H` — Adobe-GB1, GB 2312-80 EUC encoding, horizontal.
  GbEucH
  /// `GB-EUC-V` — Adobe-GB1, GB 2312-80 EUC encoding, vertical.
  GbEucV
  /// `GBK-EUC-H` — Adobe-GB1, GBK encoding (Microsoft code page 936), horizontal.
  GbkEucH
  /// `GBK-EUC-V` — Adobe-GB1, GBK encoding (Microsoft code page 936), vertical.
  GbkEucV
  /// `GBK2K-H` — Adobe-GB1, GB 18030-2000 encoding, horizontal.
  Gbk2kH
  /// `GBK2K-V` — Adobe-GB1, GB 18030-2000 encoding, vertical.
  Gbk2kV
  /// `GBKp-EUC-H` — Adobe-GB1, GBK with proportional Roman, horizontal.
  GbkpEucH
  /// `GBKp-EUC-V` — Adobe-GB1, GBK with proportional Roman, vertical.
  GbkpEucV
  /// `GBpc-EUC-H` — Adobe-GB1, Mac GB 2312 (simplified) EUC encoding, horizontal.
  GbpcEucH
  /// `GBpc-EUC-V` — Adobe-GB1, Mac GB 2312 (simplified) EUC encoding, vertical.
  GbpcEucV

  // ── Adobe-Japan1 (Japanese) ── JIS encoding ──
  /// `H` — Adobe-Japan1, JIS X 0208 row-cell encoding, horizontal.
  H

  // ── Adobe-CNS1 (Traditional Chinese) ── Hong Kong SCS ──
  /// `HKscs-B5-H` — Adobe-CNS1, Hong Kong SCS (Big Five with HKSCS extensions), horizontal.
  HKscsB5H
  /// `HKscs-B5-V` — Adobe-CNS1, Hong Kong SCS (Big Five with HKSCS extensions), vertical.
  HKscsB5V

  // ── Adobe-Identity ──
  /// `Identity-H` — Adobe-Identity, two-byte identity mapping, horizontal.
  /// Character codes map directly to CIDs (i.e. CID = character code).
  IdentityH
  /// `Identity-V` — Adobe-Identity, two-byte identity mapping, vertical.
  /// Character codes map directly to CIDs (i.e. CID = character code).
  IdentityV

  // ── Adobe-Korea1 (Korean) ──
  /// `KSC-EUC-H` — Adobe-Korea1, KS X 1001:1992 EUC-KR encoding, horizontal.
  KscEucH
  /// `KSC-EUC-V` — Adobe-Korea1, KS X 1001:1992 EUC-KR encoding, vertical.
  KscEucV
  /// `KSCms-UHC-H` — Adobe-Korea1, Microsoft UHC (Unified Hangul Code, code page 949), horizontal.
  KscmsUhcH
  /// `KSCms-UHC-HW-H` — Adobe-Korea1, Microsoft UHC with half-width Roman, horizontal.
  KscmsUhcHwH
  /// `KSCms-UHC-HW-V` — Adobe-Korea1, Microsoft UHC with half-width Roman, vertical.
  KscmsUhcHwV
  /// `KSCms-UHC-V` — Adobe-Korea1, Microsoft UHC (Unified Hangul Code, code page 949), vertical.
  KscmsUhcV
  /// `KSCpc-EUC-H` — Adobe-Korea1, Mac KS X 1001:1992 EUC-KR encoding, horizontal.
  KscpcEucH

  // ── Adobe-CNS1 (Traditional Chinese) ── Unicode encodings ──
  /// `UniCNS-UCS2-H` — Adobe-CNS1, Unicode UCS-2 encoding, horizontal.
  UniCnsUcs2H
  /// `UniCNS-UCS2-V` — Adobe-CNS1, Unicode UCS-2 encoding, vertical.
  UniCnsUcs2V
  /// `UniCNS-UTF16-H` — Adobe-CNS1, Unicode UTF-16 encoding, horizontal.
  UniCnsUtf16H
  /// `UniCNS-UTF16-V` — Adobe-CNS1, Unicode UTF-16 encoding, vertical.
  UniCnsUtf16V

  // ── Adobe-GB1 (Simplified Chinese) ── Unicode encodings ──
  /// `UniGB-UCS2-H` — Adobe-GB1, Unicode UCS-2 encoding, horizontal.
  UniGbUcs2H
  /// `UniGB-UCS2-V` — Adobe-GB1, Unicode UCS-2 encoding, vertical.
  UniGbUcs2V
  /// `UniGB-UTF16-H` — Adobe-GB1, Unicode UTF-16 encoding, horizontal.
  UniGbUtf16H
  /// `UniGB-UTF16-V` — Adobe-GB1, Unicode UTF-16 encoding, vertical.
  UniGbUtf16V

  // ── Adobe-Japan1 (Japanese) ── Unicode encodings ──
  /// `UniJIS-UCS2-H` — Adobe-Japan1, Unicode UCS-2 encoding, horizontal.
  UniJisUcs2H
  /// `UniJIS-UCS2-HW-H` — Adobe-Japan1, Unicode UCS-2 with half-width Roman, horizontal.
  UniJisUcs2HwH
  /// `UniJIS-UCS2-HW-V` — Adobe-Japan1, Unicode UCS-2 with half-width Roman, vertical.
  UniJisUcs2HwV
  /// `UniJIS-UCS2-V` — Adobe-Japan1, Unicode UCS-2 encoding, vertical.
  UniJisUcs2V
  /// `UniJIS-UTF16-H` — Adobe-Japan1, Unicode UTF-16 encoding, horizontal.
  UniJisUtf16H
  /// `UniJIS-UTF16-V` — Adobe-Japan1, Unicode UTF-16 encoding, vertical.
  UniJisUtf16V

  // ── Adobe-Korea1 (Korean) ── Unicode encodings ──
  /// `UniKS-UCS2-H` — Adobe-Korea1, Unicode UCS-2 encoding, horizontal.
  UniKsUcs2H
  /// `UniKS-UCS2-V` — Adobe-Korea1, Unicode UCS-2 encoding, vertical.
  UniKsUcs2V
  /// `UniKS-UTF16-H` — Adobe-Korea1, Unicode UTF-16 encoding, horizontal.
  UniKsUtf16H
  /// `UniKS-UTF16-V` — Adobe-Korea1, Unicode UTF-16 encoding, vertical.
  UniKsUtf16V

  // ── Adobe-Japan1 (Japanese) ── JIS encoding ──
  /// `V` — Adobe-Japan1, JIS X 0208 row-cell encoding, vertical.
  V
  /// A custom (non-predefined) `CMap` name.
  Custom(BytesView)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CMapName with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CMapName with @debug.Debug::{to_repr}

///|
/// Create a `CMapName` from raw bytes.
pub fn CMapName::from_bytes(name : BytesView) -> CMapName {
  match name {
    b"83pv-RKSJ-H" => N83pvRksjH
    b"90ms-RKSJ-H" => N90msRksjH
    b"90ms-RKSJ-V" => N90msRksjV
    b"90msp-RKSJ-H" => N90mspRksjH
    b"90msp-RKSJ-V" => N90mspRksjV
    b"90pv-RKSJ-H" => N90pvRksjH
    b"Add-RKSJ-H" => AddRksjH
    b"Add-RKSJ-V" => AddRksjV
    b"Adobe-CNS1-UCS2" => AdobeCns1Ucs2
    b"Adobe-GB1-UCS2" => AdobeGb1Ucs2
    b"Adobe-Japan1-UCS2" => AdobeJapan1Ucs2
    b"Adobe-Korea1-UCS2" => AdobeKorea1Ucs2
    b"B5pc-H" => B5pcH
    b"B5pc-V" => B5pcV
    b"CNS-EUC-H" => CnsEucH
    b"CNS-EUC-V" => CnsEucV
    b"ETen-B5-H" => ETenB5H
    b"ETen-B5-V" => ETenB5V
    b"ETenms-B5-H" => ETenmsB5H
    b"ETenms-B5-V" => ETenmsB5V
    b"EUC-H" => EucH
    b"EUC-V" => EucV
    b"Ext-RKSJ-H" => ExtRksjH
    b"Ext-RKSJ-V" => ExtRksjV
    b"GB-EUC-H" => GbEucH
    b"GB-EUC-V" => GbEucV
    b"GBK-EUC-H" => GbkEucH
    b"GBK-EUC-V" => GbkEucV
    b"GBK2K-H" => Gbk2kH
    b"GBK2K-V" => Gbk2kV
    b"GBKp-EUC-H" => GbkpEucH
    b"GBKp-EUC-V" => GbkpEucV
    b"GBpc-EUC-H" => GbpcEucH
    b"GBpc-EUC-V" => GbpcEucV
    b"H" => H
    b"HKscs-B5-H" => HKscsB5H
    b"HKscs-B5-V" => HKscsB5V
    b"Identity-H" => IdentityH
    b"Identity-V" => IdentityV
    b"KSC-EUC-H" => KscEucH
    b"KSC-EUC-V" => KscEucV
    b"KSCms-UHC-H" => KscmsUhcH
    b"KSCms-UHC-HW-H" => KscmsUhcHwH
    b"KSCms-UHC-HW-V" => KscmsUhcHwV
    b"KSCms-UHC-V" => KscmsUhcV
    b"KSCpc-EUC-H" => KscpcEucH
    b"UniCNS-UCS2-H" => UniCnsUcs2H
    b"UniCNS-UCS2-V" => UniCnsUcs2V
    b"UniCNS-UTF16-H" => UniCnsUtf16H
    b"UniCNS-UTF16-V" => UniCnsUtf16V
    b"UniGB-UCS2-H" => UniGbUcs2H
    b"UniGB-UCS2-V" => UniGbUcs2V
    b"UniGB-UTF16-H" => UniGbUtf16H
    b"UniGB-UTF16-V" => UniGbUtf16V
    b"UniJIS-UCS2-H" => UniJisUcs2H
    b"UniJIS-UCS2-HW-H" => UniJisUcs2HwH
    b"UniJIS-UCS2-HW-V" => UniJisUcs2HwV
    b"UniJIS-UCS2-V" => UniJisUcs2V
    b"UniJIS-UTF16-H" => UniJisUtf16H
    b"UniJIS-UTF16-V" => UniJisUtf16V
    b"UniKS-UCS2-H" => UniKsUcs2H
    b"UniKS-UCS2-V" => UniKsUcs2V
    b"UniKS-UTF16-H" => UniKsUtf16H
    b"UniKS-UTF16-V" => UniKsUtf16V
    b"V" => V
    _ => Custom(name)
  }
}

///|
/// Convert the `CMapName` back to its raw byte representation.
pub fn CMapName::to_bytes(self : CMapName) -> BytesView {
  match self {
    N83pvRksjH => b"83pv-RKSJ-H"
    N90msRksjH => b"90ms-RKSJ-H"
    N90msRksjV => b"90ms-RKSJ-V"
    N90mspRksjH => b"90msp-RKSJ-H"
    N90mspRksjV => b"90msp-RKSJ-V"
    N90pvRksjH => b"90pv-RKSJ-H"
    AddRksjH => b"Add-RKSJ-H"
    AddRksjV => b"Add-RKSJ-V"
    AdobeCns1Ucs2 => b"Adobe-CNS1-UCS2"
    AdobeGb1Ucs2 => b"Adobe-GB1-UCS2"
    AdobeJapan1Ucs2 => b"Adobe-Japan1-UCS2"
    AdobeKorea1Ucs2 => b"Adobe-Korea1-UCS2"
    B5pcH => b"B5pc-H"
    B5pcV => b"B5pc-V"
    CnsEucH => b"CNS-EUC-H"
    CnsEucV => b"CNS-EUC-V"
    ETenB5H => b"ETen-B5-H"
    ETenB5V => b"ETen-B5-V"
    ETenmsB5H => b"ETenms-B5-H"
    ETenmsB5V => b"ETenms-B5-V"
    EucH => b"EUC-H"
    EucV => b"EUC-V"
    ExtRksjH => b"Ext-RKSJ-H"
    ExtRksjV => b"Ext-RKSJ-V"
    GbEucH => b"GB-EUC-H"
    GbEucV => b"GB-EUC-V"
    GbkEucH => b"GBK-EUC-H"
    GbkEucV => b"GBK-EUC-V"
    Gbk2kH => b"GBK2K-H"
    Gbk2kV => b"GBK2K-V"
    GbkpEucH => b"GBKp-EUC-H"
    GbkpEucV => b"GBKp-EUC-V"
    GbpcEucH => b"GBpc-EUC-H"
    GbpcEucV => b"GBpc-EUC-V"
    H => b"H"
    HKscsB5H => b"HKscs-B5-H"
    HKscsB5V => b"HKscs-B5-V"
    IdentityH => b"Identity-H"
    IdentityV => b"Identity-V"
    KscEucH => b"KSC-EUC-H"
    KscEucV => b"KSC-EUC-V"
    KscmsUhcH => b"KSCms-UHC-H"
    KscmsUhcHwH => b"KSCms-UHC-HW-H"
    KscmsUhcHwV => b"KSCms-UHC-HW-V"
    KscmsUhcV => b"KSCms-UHC-V"
    KscpcEucH => b"KSCpc-EUC-H"
    UniCnsUcs2H => b"UniCNS-UCS2-H"
    UniCnsUcs2V => b"UniCNS-UCS2-V"
    UniCnsUtf16H => b"UniCNS-UTF16-H"
    UniCnsUtf16V => b"UniCNS-UTF16-V"
    UniGbUcs2H => b"UniGB-UCS2-H"
    UniGbUcs2V => b"UniGB-UCS2-V"
    UniGbUtf16H => b"UniGB-UTF16-H"
    UniGbUtf16V => b"UniGB-UTF16-V"
    UniJisUcs2H => b"UniJIS-UCS2-H"
    UniJisUcs2HwH => b"UniJIS-UCS2-HW-H"
    UniJisUcs2HwV => b"UniJIS-UCS2-HW-V"
    UniJisUcs2V => b"UniJIS-UCS2-V"
    UniJisUtf16H => b"UniJIS-UTF16-H"
    UniJisUtf16V => b"UniJIS-UTF16-V"
    UniKsUcs2H => b"UniKS-UCS2-H"
    UniKsUcs2V => b"UniKS-UCS2-V"
    UniKsUtf16H => b"UniKS-UTF16-H"
    UniKsUtf16V => b"UniKS-UTF16-V"
    V => b"V"
    Custom(name) => name
  }
}
