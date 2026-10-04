// Port of wasmparser 0.228.0 `src/binary_reader/simd.rs`.

///|
fn BinaryReader::read_0xfd_operator(
  self : BinaryReader,
  pos : Int,
) -> Operator raise BinaryReaderError {
  let code = self.read_var_u32()
  match code {
    0x00 => V128Load(memarg=self.read_memarg(4))
    0x01 => V128Load8x8S(memarg=self.read_memarg(3))
    0x02 => V128Load8x8U(memarg=self.read_memarg(3))
    0x03 => V128Load16x4S(memarg=self.read_memarg(3))
    0x04 => V128Load16x4U(memarg=self.read_memarg(3))
    0x05 => V128Load32x2S(memarg=self.read_memarg(3))
    0x06 => V128Load32x2U(memarg=self.read_memarg(3))
    0x07 => V128Load8Splat(memarg=self.read_memarg(0))
    0x08 => V128Load16Splat(memarg=self.read_memarg(1))
    0x09 => V128Load32Splat(memarg=self.read_memarg(2))
    0x0a => V128Load64Splat(memarg=self.read_memarg(3))
    0x0b => V128Store(memarg=self.read_memarg(4))
    0x0c => V128Const(value=self.read_v128())
    0x0e => I8x16Swizzle
    0x0f => I8x16Splat
    0x10 => I16x8Splat
    0x11 => I32x4Splat
    0x12 => I64x2Splat
    0x13 => F32x4Splat
    0x14 => F64x2Splat
    0x15 => I8x16ExtractLaneS(lane=self.read_lane_index(16))
    0x16 => I8x16ExtractLaneU(lane=self.read_lane_index(16))
    0x17 => I8x16ReplaceLane(lane=self.read_lane_index(16))
    0x18 => I16x8ExtractLaneS(lane=self.read_lane_index(8))
    0x19 => I16x8ExtractLaneU(lane=self.read_lane_index(8))
    0x1a => I16x8ReplaceLane(lane=self.read_lane_index(8))
    0x1b => I32x4ExtractLane(lane=self.read_lane_index(4))
    0x1c => I32x4ReplaceLane(lane=self.read_lane_index(4))
    0x1d => I64x2ExtractLane(lane=self.read_lane_index(2))
    0x1e => I64x2ReplaceLane(lane=self.read_lane_index(2))
    0x1f => F32x4ExtractLane(lane=self.read_lane_index(4))
    0x20 => F32x4ReplaceLane(lane=self.read_lane_index(4))
    0x21 => F64x2ExtractLane(lane=self.read_lane_index(2))
    0x22 => F64x2ReplaceLane(lane=self.read_lane_index(2))
    0x23 => I8x16Eq
    0x24 => I8x16Ne
    0x25 => I8x16LtS
    0x26 => I8x16LtU
    0x27 => I8x16GtS
    0x28 => I8x16GtU
    0x29 => I8x16LeS
    0x2a => I8x16LeU
    0x2b => I8x16GeS
    0x2c => I8x16GeU
    0x2d => I16x8Eq
    0x2e => I16x8Ne
    0x2f => I16x8LtS
    0x30 => I16x8LtU
    0x31 => I16x8GtS
    0x32 => I16x8GtU
    0x33 => I16x8LeS
    0x34 => I16x8LeU
    0x35 => I16x8GeS
    0x36 => I16x8GeU
    0x37 => I32x4Eq
    0x38 => I32x4Ne
    0x39 => I32x4LtS
    0x3a => I32x4LtU
    0x3b => I32x4GtS
    0x3c => I32x4GtU
    0x3d => I32x4LeS
    0x3e => I32x4LeU
    0x3f => I32x4GeS
    0x40 => I32x4GeU
    0x41 => F32x4Eq
    0x42 => F32x4Ne
    0x43 => F32x4Lt
    0x44 => F32x4Gt
    0x45 => F32x4Le
    0x46 => F32x4Ge
    0x47 => F64x2Eq
    0x48 => F64x2Ne
    0x49 => F64x2Lt
    0x4a => F64x2Gt
    0x4b => F64x2Le
    0x4c => F64x2Ge
    0x4d => V128Not
    0x4e => V128And
    0x4f => V128AndNot
    0x50 => V128Or
    0x51 => V128Xor
    0x52 => V128Bitselect
    0x53 => V128AnyTrue
    0x54 => {
      let memarg = self.read_memarg(0)
      let lane = self.read_lane_index(16)
      V128Load8Lane(memarg~, lane~)
    }
    0x55 => {
      let memarg = self.read_memarg(1)
      let lane = self.read_lane_index(8)
      V128Load16Lane(memarg~, lane~)
    }
    0x56 => {
      let memarg = self.read_memarg(2)
      let lane = self.read_lane_index(4)
      V128Load32Lane(memarg~, lane~)
    }
    0x57 => {
      let memarg = self.read_memarg(3)
      let lane = self.read_lane_index(2)
      V128Load64Lane(memarg~, lane~)
    }
    0x58 => {
      let memarg = self.read_memarg(0)
      let lane = self.read_lane_index(16)
      V128Store8Lane(memarg~, lane~)
    }
    0x59 => {
      let memarg = self.read_memarg(1)
      let lane = self.read_lane_index(8)
      V128Store16Lane(memarg~, lane~)
    }
    0x5a => {
      let memarg = self.read_memarg(2)
      let lane = self.read_lane_index(4)
      V128Store32Lane(memarg~, lane~)
    }
    0x5b => {
      let memarg = self.read_memarg(3)
      let lane = self.read_lane_index(2)
      V128Store64Lane(memarg~, lane~)
    }
    0x5c => V128Load32Zero(memarg=self.read_memarg(2))
    0x5d => V128Load64Zero(memarg=self.read_memarg(3))
    0x5e => F32x4DemoteF64x2Zero
    0x5f => F64x2PromoteLowF32x4
    0x60 => I8x16Abs
    0x61 => I8x16Neg
    0x62 => I8x16Popcnt
    0x63 => I8x16AllTrue
    0x64 => I8x16Bitmask
    0x65 => I8x16NarrowI16x8S
    0x66 => I8x16NarrowI16x8U
    0x67 => F32x4Ceil
    0x68 => F32x4Floor
    0x69 => F32x4Trunc
    0x6a => F32x4Nearest
    0x6b => I8x16Shl
    0x6c => I8x16ShrS
    0x6d => I8x16ShrU
    0x6e => I8x16Add
    0x6f => I8x16AddSatS
    0x70 => I8x16AddSatU
    0x71 => I8x16Sub
    0x72 => I8x16SubSatS
    0x73 => I8x16SubSatU
    0x74 => F64x2Ceil
    0x75 => F64x2Floor
    0x76 => I8x16MinS
    0x77 => I8x16MinU
    0x78 => I8x16MaxS
    0x79 => I8x16MaxU
    0x7a => F64x2Trunc
    0x7b => I8x16AvgrU
    0x7c => I16x8ExtAddPairwiseI8x16S
    0x7d => I16x8ExtAddPairwiseI8x16U
    0x7e => I32x4ExtAddPairwiseI16x8S
    0x7f => I32x4ExtAddPairwiseI16x8U
    0x80 => I16x8Abs
    0x81 => I16x8Neg
    0x82 => I16x8Q15MulrSatS
    0x83 => I16x8AllTrue
    0x84 => I16x8Bitmask
    0x85 => I16x8NarrowI32x4S
    0x86 => I16x8NarrowI32x4U
    0x87 => I16x8ExtendLowI8x16S
    0x88 => I16x8ExtendHighI8x16S
    0x89 => I16x8ExtendLowI8x16U
    0x8a => I16x8ExtendHighI8x16U
    0x8b => I16x8Shl
    0x8c => I16x8ShrS
    0x8d => I16x8ShrU
    0x8e => I16x8Add
    0x8f => I16x8AddSatS
    0x90 => I16x8AddSatU
    0x91 => I16x8Sub
    0x92 => I16x8SubSatS
    0x93 => I16x8SubSatU
    0x94 => F64x2Nearest
    0x95 => I16x8Mul
    0x96 => I16x8MinS
    0x97 => I16x8MinU
    0x98 => I16x8MaxS
    0x99 => I16x8MaxU
    0x9b => I16x8AvgrU
    0x9c => I16x8ExtMulLowI8x16S
    0x9d => I16x8ExtMulHighI8x16S
    0x9e => I16x8ExtMulLowI8x16U
    0x9f => I16x8ExtMulHighI8x16U
    0xa0 => I32x4Abs
    0xa1 => I32x4Neg
    0xa3 => I32x4AllTrue
    0xa4 => I32x4Bitmask
    0xa7 => I32x4ExtendLowI16x8S
    0xa8 => I32x4ExtendHighI16x8S
    0xa9 => I32x4ExtendLowI16x8U
    0xaa => I32x4ExtendHighI16x8U
    0xab => I32x4Shl
    0xac => I32x4ShrS
    0xad => I32x4ShrU
    0xae => I32x4Add
    0xb1 => I32x4Sub
    0xb5 => I32x4Mul
    0xb6 => I32x4MinS
    0xb7 => I32x4MinU
    0xb8 => I32x4MaxS
    0xb9 => I32x4MaxU
    0xba => I32x4DotI16x8S
    0xbc => I32x4ExtMulLowI16x8S
    0xbd => I32x4ExtMulHighI16x8S
    0xbe => I32x4ExtMulLowI16x8U
    0xbf => I32x4ExtMulHighI16x8U
    0xc0 => I64x2Abs
    0xc1 => I64x2Neg
    0xc3 => I64x2AllTrue
    0xc4 => I64x2Bitmask
    0xc7 => I64x2ExtendLowI32x4S
    0xc8 => I64x2ExtendHighI32x4S
    0xc9 => I64x2ExtendLowI32x4U
    0xca => I64x2ExtendHighI32x4U
    0xcb => I64x2Shl
    0xcc => I64x2ShrS
    0xcd => I64x2ShrU
    0xce => I64x2Add
    0xd1 => I64x2Sub
    0xd5 => I64x2Mul
    0xd6 => I64x2Eq
    0xd7 => I64x2Ne
    0xd8 => I64x2LtS
    0xd9 => I64x2GtS
    0xda => I64x2LeS
    0xdb => I64x2GeS
    0xdc => I64x2ExtMulLowI32x4S
    0xdd => I64x2ExtMulHighI32x4S
    0xde => I64x2ExtMulLowI32x4U
    0xdf => I64x2ExtMulHighI32x4U
    0xe0 => F32x4Abs
    0xe1 => F32x4Neg
    0xe3 => F32x4Sqrt
    0xe4 => F32x4Add
    0xe5 => F32x4Sub
    0xe6 => F32x4Mul
    0xe7 => F32x4Div
    0xe8 => F32x4Min
    0xe9 => F32x4Max
    0xea => F32x4PMin
    0xeb => F32x4PMax
    0xec => F64x2Abs
    0xed => F64x2Neg
    0xef => F64x2Sqrt
    0xf0 => F64x2Add
    0xf1 => F64x2Sub
    0xf2 => F64x2Mul
    0xf3 => F64x2Div
    0xf4 => F64x2Min
    0xf5 => F64x2Max
    0xf6 => F64x2PMin
    0xf7 => F64x2PMax
    0xf8 => I32x4TruncSatF32x4S
    0xf9 => I32x4TruncSatF32x4U
    0xfa => F32x4ConvertI32x4S
    0xfb => F32x4ConvertI32x4U
    0xfc => I32x4TruncSatF64x2SZero
    0xfd => I32x4TruncSatF64x2UZero
    0xfe => F64x2ConvertLowI32x4S
    0xff => F64x2ConvertLowI32x4U
    0x100 => I8x16RelaxedSwizzle
    0x101 => I32x4RelaxedTruncF32x4S
    0x102 => I32x4RelaxedTruncF32x4U
    0x103 => I32x4RelaxedTruncF64x2SZero
    0x104 => I32x4RelaxedTruncF64x2UZero
    0x105 => F32x4RelaxedMadd
    0x106 => F32x4RelaxedNmadd
    0x107 => F64x2RelaxedMadd
    0x108 => F64x2RelaxedNmadd
    0x109 => I8x16RelaxedLaneselect
    0x10a => I16x8RelaxedLaneselect
    0x10b => I32x4RelaxedLaneselect
    0x10c => I64x2RelaxedLaneselect
    0x10d => F32x4RelaxedMin
    0x10e => F32x4RelaxedMax
    0x10f => F64x2RelaxedMin
    0x110 => F64x2RelaxedMax
    0x111 => I16x8RelaxedQ15mulrS
    0x112 => I16x8RelaxedDotI8x16I7x16S
    0x0d => {
      let lanes : FixedArray[Byte] = FixedArray::make(16, 0)
      for i in 0..<16 {
        lanes[i] = self.read_lane_index(32)
      }
      I8x16Shuffle(lanes~)
    }
    _ => bail(pos, "unknown 0xfd subopcode: 0x\{code.to_string(radix=16)}")
  }
}
