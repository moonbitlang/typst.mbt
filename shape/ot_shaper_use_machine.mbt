// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_use_machine.rs` (Ragel-generated
// from `ot_shaper_use_machine.rl`). The tables are generated into
// `ot_shaper_use_machine_gen.mbt`; the driver below is ported by hand.

///|
// `IndependentCluster` is never built upstream either
// (rustybuzz 0.20.1 src/hb/ot_shaper_use_machine.rs:278); it keeps the numbering.
#warnings("-unused_constructor")
priv enum UseSyllableType {
  IndependentCluster
  ViramaTerminatedCluster
  SakotTerminatedCluster
  StandardCluster
  NumberJoinerTerminatedCluster
  NumeralCluster
  SymbolCluster
  HieroglyphCluster
  BrokenCluster
  NonCluster
}

///|
/// `SyllableType as u8`
fn UseSyllableType::to_int(self : UseSyllableType) -> Int {
  match self {
    IndependentCluster => 0
    ViramaTerminatedCluster => 1
    SakotTerminatedCluster => 2
    StandardCluster => 3
    NumberJoinerTerminatedCluster => 4
    NumeralCluster => 5
    SymbolCluster => 6
    HieroglyphCluster => 7
    BrokenCluster => 8
    NonCluster => 9
  }
}

///|
/// `find_syllables` of `ot_shaper_use_machine.rs`.
fn find_syllables_use(buffer : Buffer) -> Unit {
  let mut cs = 0
  let infos = buffer.info
  let p0 = MachineCursor::new(infos, included_use)
  let mut p = p0
  let mut ts = p0
  let mut te = p0
  let pe = p.end()
  let eof = p.end()
  let syllable_serial = Ref(1)

  // Please manually replace assignments of 0 to p, ts, and te
  // to use p0 instead

  fn found_syllable_(
    ts : MachineCursor[GlyphInfo],
    te : MachineCursor[GlyphInfo],
    kind : UseSyllableType,
  ) {
    found_syllable_use(ts.index(), te.index(), syllable_serial, kind, infos)
  }

  {
    cs = USE_SYLLABLE_MACHINE_START
    ts = p0
    te = p0
  }
  let mut _klen = 0
  let mut _trans = 0
  let mut _keys : Int = 0
  let mut _acts : Int = 0
  let mut _nacts = 0
  let mut __have = 0
  while !p.equal(pe) || p.equal(eof) {
    // '_again
    _acts = use_syllable_machine_from_state_actions[cs]
    _nacts = use_syllable_machine_actions[_acts]
    _acts += 1
    while _nacts > 0 {
      match use_syllable_machine_actions[_acts] {
        1 => ts = p
        _ => ()
      }
      _nacts -= 1
      _acts += 1
    }
    if p.equal(eof) {
      if use_syllable_machine_eof_trans[cs] > 0 {
        _trans = use_syllable_machine_eof_trans[cs] - 1
      }
    } else {
      _keys = use_syllable_machine_key_offsets[cs]
      _trans = use_syllable_machine_index_offsets[cs]
      _klen = use_syllable_machine_single_lengths[cs]
      __have = 0
      if _klen > 0 {
        let mut _lower : Int = _keys
        let mut _upper : Int = _keys + _klen - 1
        let mut _mid : Int = 0
        while true {
          if _upper < _lower {
            _keys += _klen
            _trans += _klen
            break
          }
          _mid = _lower + ((_upper - _lower) >> 1)
          if infos[p.index()].use_category() <
            use_syllable_machine_trans_keys[_mid] {
            _upper = _mid - 1
          } else if infos[p.index()].use_category() >
            use_syllable_machine_trans_keys[_mid] {
            _lower = _mid + 1
          } else {
            __have = 1
            _trans += _mid - _keys
            break
          }
        }
      }
      _klen = use_syllable_machine_range_lengths[cs]
      if __have == 0 && _klen > 0 {
        let mut _lower : Int = _keys
        let mut _upper : Int = _keys + (_klen << 1) - 2
        let mut _mid : Int = 0
        while true {
          if _upper < _lower {
            _trans += _klen
            break
          }
          _mid = _lower + (((_upper - _lower) >> 1) & (1).lnot())
          if infos[p.index()].use_category() <
            use_syllable_machine_trans_keys[_mid] {
            _upper = _mid - 2
          } else if infos[p.index()].use_category() >
            use_syllable_machine_trans_keys[_mid + 1] {
            _lower = _mid + 2
          } else {
            _trans += (_mid - _keys) >> 1
            break
          }
        }
      }
    }
    cs = use_syllable_machine_cond_targs[_trans]
    if use_syllable_machine_cond_actions[_trans] != 0 {
      _acts = use_syllable_machine_cond_actions[_trans]
      _nacts = use_syllable_machine_actions[_acts]
      _acts += 1
      while _nacts > 0 {
        match use_syllable_machine_actions[_acts] {
          2 => te = p.add(1)
          3 => {
            te = p.add(1)
            found_syllable_(ts, te, ViramaTerminatedCluster)
          }
          4 => {
            te = p.add(1)
            found_syllable_(ts, te, SakotTerminatedCluster)
          }
          5 => {
            te = p.add(1)
            found_syllable_(ts, te, StandardCluster)
          }
          6 => {
            te = p.add(1)
            found_syllable_(ts, te, NumberJoinerTerminatedCluster)
          }
          7 => {
            te = p.add(1)
            found_syllable_(ts, te, NumeralCluster)
          }
          8 => {
            te = p.add(1)
            found_syllable_(ts, te, SymbolCluster)
          }
          9 => {
            te = p.add(1)
            found_syllable_(ts, te, HieroglyphCluster)
          }
          10 => {
            te = p.add(1)
            found_syllable_(ts, te, BrokenCluster)
            buffer.scratch_flags = buffer.scratch_flags |
              HB_BUFFER_SCRATCH_FLAG_HAS_BROKEN_SYLLABLE
          }
          11 => {
            te = p.add(1)
            found_syllable_(ts, te, NonCluster)
          }
          12 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, ViramaTerminatedCluster)
          }
          13 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, SakotTerminatedCluster)
          }
          14 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, StandardCluster)
          }
          15 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, NumberJoinerTerminatedCluster)
          }
          16 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, NumeralCluster)
          }
          17 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, SymbolCluster)
          }
          18 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, HieroglyphCluster)
          }
          19 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, BrokenCluster)
            buffer.scratch_flags = buffer.scratch_flags |
              HB_BUFFER_SCRATCH_FLAG_HAS_BROKEN_SYLLABLE
          }
          20 => {
            te = p
            p = p.sub(1)
            found_syllable_(ts, te, NonCluster)
          }
          21 => {
            p = te.sub(1)
            found_syllable_(ts, te, SymbolCluster)
          }
          _ => ()
        }
        _nacts -= 1
        _acts += 1
      }
    }
    // break '_again
    if p.equal(eof) {
      if cs >= 1 {
        break
      }
    } else {
      _acts = use_syllable_machine_to_state_actions[cs]
      _nacts = use_syllable_machine_actions[_acts]
      _acts += 1
      while _nacts > 0 {
        match use_syllable_machine_actions[_acts] {
          0 => ts = p0
          _ => ()
        }
        _nacts -= 1
        _acts += 1
      }
      p = p.add(1)
      continue
    }
    break
  }
}

///|
/// `found_syllable` of `ot_shaper_use_machine.rs`.
fn found_syllable_use(
  start : Int,
  end : Int,
  syllable_serial : Ref[Int],
  kind : UseSyllableType,
  buffer : Array[GlyphInfo],
) -> Unit {
  for i in start..<end {
    buffer[i].set_syllable((syllable_serial.val << 4) | kind.to_int())
  }
  syllable_serial.val += 1
  if syllable_serial.val == 16 {
    syllable_serial.val = 1
  }
}

///|
fn not_ccs_default_ignorable(i : GlyphInfo) -> Bool {
  i.use_category() != USE_CGJ
}

///|
/// `included` of `ot_shaper_use_machine.rs`.
fn included_use(infos : Array[GlyphInfo], i : Int) -> Bool {
  let glyph = infos[i]
  if !not_ccs_default_ignorable(glyph) {
    return false
  }
  if glyph.use_category() == USE_ZWNJ {
    for glyph2 in infos[i + 1:] {
      if not_ccs_default_ignorable(glyph2) {
        return !glyph2.is_unicode_mark()
      }
    }
  }
  true
}
