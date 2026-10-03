// Port of `hayro-ccitt/src/state_machine.rs`: state machine for decoding
// CCITT run-length codes.
//
// CCITT assigns binary codes to integers that indicate how many pixels are
// of that specific color. The binary codes vary depending on whether we are
// decoding black pixels or white pixels.
//
// To achieve this, we create a simple "state-machine" by building a tree
// of nodes, where each node represents one binary digit and can contain
// up two children based on whether the next digit is 0 or 1 (basically a
// huffman tree). Then, we simply can read bit by bit and traverse the
// tree to find the corresponding black/white code for the given bit sequence.
//
// The states are built once at first use (upstream builds them in `const
// fn`s).

///|
/// The flag indicating whether the state is terminal.
const TERMINAL : Int = 0x8000

///|
/// The mask used to get the actual value from a terminal state.
const VALUE_MASK : Int = 0x1FFF

///|
/// An invalid state.
const INVALID : Int = 0xFFFF

///|
priv struct State {
  mut on_0 : Int
  mut on_1 : Int
}

///|
fn State::new() -> State {
  { on_0: INVALID, on_1: INVALID, }
}

///|
/// Insert a single code into the state machine.
/// Returns the new number of states.
fn insert_code(
  states : FixedArray[State],
  num_states : Int,
  run_length : Int,
  code_length : Int,
  code : Int,
) -> Int {
  let mut num_states = num_states
  let mut current_state = 0
  for i in 0..<code_length {
    let bit = (code >> (code_length - 1 - i)) & 1
    let is_last_bit = i == code_length - 1
    let next = if bit == 0 {
      states[current_state].on_0
    } else {
      states[current_state].on_1
    }
    if is_last_bit {
      let result = TERMINAL | (run_length & VALUE_MASK)
      if bit == 0 {
        states[current_state].on_0 = result
      } else {
        states[current_state].on_1 = result
      }
    } else if next == INVALID {
      // Create a new state.
      let new_state = num_states
      num_states += 1
      if bit == 0 {
        states[current_state].on_0 = new_state
      } else {
        states[current_state].on_1 = new_state
      }
      current_state = new_state
    } else {
      // Follow existing transition.
      current_state = next
    }
  }
  num_states
}

///|
fn insert_codes(
  states : FixedArray[State],
  num_states : Int,
  codes : FixedArray[(Int, Int, Int)],
) -> Int {
  let mut num_states = num_states
  for c in codes {
    let (run_length, code_length, code) = c
    num_states = insert_code(states, num_states, run_length, code_length, code)
  }
  num_states
}

///|
fn build_run_states(
  n : Int,
  terminating : FixedArray[(Int, Int, Int)],
  makeup : FixedArray[(Int, Int, Int)],
) -> FixedArray[State] {
  let states = FixedArray::makei(n, _ => State::new())
  let mut num_states = 1
  num_states = insert_codes(states, num_states, terminating)
  num_states = insert_codes(states, num_states, makeup)
  ignore(insert_codes(states, num_states, common_makeup))
  states
}

///|
let white_states_cell : Ref[FixedArray[State]?] = { val: None, }

///|
/// List of states for white color codes.
fn white_states() -> FixedArray[State] {
  match white_states_cell.val {
    Some(s) => s
    None => {
      let s = build_run_states(104, white_terminating, white_makeup)
      white_states_cell.val = Some(s)
      s
    }
  }
}

///|
let black_states_cell : Ref[FixedArray[State]?] = { val: None, }

///|
/// List of states for black color codes.
fn black_states() -> FixedArray[State] {
  match black_states_cell.val {
    Some(s) => s
    None => {
      let s = build_run_states(104, black_terminating, black_makeup)
      black_states_cell.val = Some(s)
      s
    }
  }
}

///|
let mode_states_cell : Ref[FixedArray[State]?] = { val: None, }

///|
/// List of states for coding modes.
fn mode_states() -> FixedArray[State] {
  match mode_states_cell.val {
    Some(s) => s
    None => {
      let s = FixedArray::makei(9, _ => State::new())
      ignore(insert_codes(s, 1, mode_codes))
      mode_states_cell.val = Some(s)
      s
    }
  }
}

///|
/// White terminating codes (T.4 Table 2/T.4, T.6 Table 2/T.6).
let white_terminating : FixedArray[(Int, Int, Int)] = [
  (0, 8, 0b00110101),
  (1, 6, 0b000111),
  (2, 4, 0b0111),
  (3, 4, 0b1000),
  (4, 4, 0b1011),
  (5, 4, 0b1100),
  (6, 4, 0b1110),
  (7, 4, 0b1111),
  (8, 5, 0b10011),
  (9, 5, 0b10100),
  (10, 5, 0b00111),
  (11, 5, 0b01000),
  (12, 6, 0b001000),
  (13, 6, 0b000011),
  (14, 6, 0b110100),
  (15, 6, 0b110101),
  (16, 6, 0b101010),
  (17, 6, 0b101011),
  (18, 7, 0b0100111),
  (19, 7, 0b0001100),
  (20, 7, 0b0001000),
  (21, 7, 0b0010111),
  (22, 7, 0b0000011),
  (23, 7, 0b0000100),
  (24, 7, 0b0101000),
  (25, 7, 0b0101011),
  (26, 7, 0b0010011),
  (27, 7, 0b0100100),
  (28, 7, 0b0011000),
  (29, 8, 0b00000010),
  (30, 8, 0b00000011),
  (31, 8, 0b00011010),
  (32, 8, 0b00011011),
  (33, 8, 0b00010010),
  (34, 8, 0b00010011),
  (35, 8, 0b00010100),
  (36, 8, 0b00010101),
  (37, 8, 0b00010110),
  (38, 8, 0b00010111),
  (39, 8, 0b00101000),
  (40, 8, 0b00101001),
  (41, 8, 0b00101010),
  (42, 8, 0b00101011),
  (43, 8, 0b00101100),
  (44, 8, 0b00101101),
  (45, 8, 0b00000100),
  (46, 8, 0b00000101),
  (47, 8, 0b00001010),
  (48, 8, 0b00001011),
  (49, 8, 0b01010010),
  (50, 8, 0b01010011),
  (51, 8, 0b01010100),
  (52, 8, 0b01010101),
  (53, 8, 0b00100100),
  (54, 8, 0b00100101),
  (55, 8, 0b01011000),
  (56, 8, 0b01011001),
  (57, 8, 0b01011010),
  (58, 8, 0b01011011),
  (59, 8, 0b01001010),
  (60, 8, 0b01001011),
  (61, 8, 0b00110010),
  (62, 8, 0b00110011),
  (63, 8, 0b00110100),
]

///|
/// White make-up codes (T.4 Table 3a/T.4, T.6 Table 3/T.6).
let white_makeup : FixedArray[(Int, Int, Int)] = [
  (64, 5, 0b11011),
  (128, 5, 0b10010),
  (192, 6, 0b010111),
  (256, 7, 0b0110111),
  (320, 8, 0b00110110),
  (384, 8, 0b00110111),
  (448, 8, 0b01100100),
  (512, 8, 0b01100101),
  (576, 8, 0b01101000),
  (640, 8, 0b01100111),
  (704, 9, 0b011001100),
  (768, 9, 0b011001101),
  (832, 9, 0b011010010),
  (896, 9, 0b011010011),
  (960, 9, 0b011010100),
  (1024, 9, 0b011010101),
  (1088, 9, 0b011010110),
  (1152, 9, 0b011010111),
  (1216, 9, 0b011011000),
  (1280, 9, 0b011011001),
  (1344, 9, 0b011011010),
  (1408, 9, 0b011011011),
  (1472, 9, 0b010011000),
  (1536, 9, 0b010011001),
  (1600, 9, 0b010011010),
  (1664, 6, 0b011000),
  (1728, 9, 0b010011011),
]

///|
/// Black terminating codes (T.4 Table 2/T.4, T.6 Table 2/T.6).
let black_terminating : FixedArray[(Int, Int, Int)] = [
  (0, 10, 0b0000110111),
  (1, 3, 0b010),
  (2, 2, 0b11),
  (3, 2, 0b10),
  (4, 3, 0b011),
  (5, 4, 0b0011),
  (6, 4, 0b0010),
  (7, 5, 0b00011),
  (8, 6, 0b000101),
  (9, 6, 0b000100),
  (10, 7, 0b0000100),
  (11, 7, 0b0000101),
  (12, 7, 0b0000111),
  (13, 8, 0b00000100),
  (14, 8, 0b00000111),
  (15, 9, 0b000011000),
  (16, 10, 0b0000010111),
  (17, 10, 0b0000011000),
  (18, 10, 0b0000001000),
  (19, 11, 0b00001100111),
  (20, 11, 0b00001101000),
  (21, 11, 0b00001101100),
  (22, 11, 0b00000110111),
  (23, 11, 0b00000101000),
  (24, 11, 0b00000010111),
  (25, 11, 0b00000011000),
  (26, 12, 0b000011001010),
  (27, 12, 0b000011001011),
  (28, 12, 0b000011001100),
  (29, 12, 0b000011001101),
  (30, 12, 0b000001101000),
  (31, 12, 0b000001101001),
  (32, 12, 0b000001101010),
  (33, 12, 0b000001101011),
  (34, 12, 0b000011010010),
  (35, 12, 0b000011010011),
  (36, 12, 0b000011010100),
  (37, 12, 0b000011010101),
  (38, 12, 0b000011010110),
  (39, 12, 0b000011010111),
  (40, 12, 0b000001101100),
  (41, 12, 0b000001101101),
  (42, 12, 0b000011011010),
  (43, 12, 0b000011011011),
  (44, 12, 0b000001010100),
  (45, 12, 0b000001010101),
  (46, 12, 0b000001010110),
  (47, 12, 0b000001010111),
  (48, 12, 0b000001100100),
  (49, 12, 0b000001100101),
  (50, 12, 0b000001010010),
  (51, 12, 0b000001010011),
  (52, 12, 0b000000100100),
  (53, 12, 0b000000110111),
  (54, 12, 0b000000111000),
  (55, 12, 0b000000100111),
  (56, 12, 0b000000101000),
  (57, 12, 0b000001011000),
  (58, 12, 0b000001011001),
  (59, 12, 0b000000101011),
  (60, 12, 0b000000101100),
  (61, 12, 0b000001011010),
  (62, 12, 0b000001100110),
  (63, 12, 0b000001100111),
]

///|
/// Black make-up codes (T.4 Table 3a/T.4, T.6 Table 3/T.6).
let black_makeup : FixedArray[(Int, Int, Int)] = [
  (64, 10, 0b0000001111),
  (128, 12, 0b000011001000),
  (192, 12, 0b000011001001),
  (256, 12, 0b000001011011),
  (320, 12, 0b000000110011),
  (384, 12, 0b000000110100),
  (448, 12, 0b000000110101),
  (512, 13, 0b0000001101100),
  (576, 13, 0b0000001101101),
  (640, 13, 0b0000001001010),
  (704, 13, 0b0000001001011),
  (768, 13, 0b0000001001100),
  (832, 13, 0b0000001001101),
  (896, 13, 0b0000001110010),
  (960, 13, 0b0000001110011),
  (1024, 13, 0b0000001110100),
  (1088, 13, 0b0000001110101),
  (1152, 13, 0b0000001110110),
  (1216, 13, 0b0000001110111),
  (1280, 13, 0b0000001010010),
  (1344, 13, 0b0000001010011),
  (1408, 13, 0b0000001010100),
  (1472, 13, 0b0000001010101),
  (1536, 13, 0b0000001011010),
  (1600, 13, 0b0000001011011),
  (1664, 13, 0b0000001100100),
  (1728, 13, 0b0000001100101),
]

///|
/// Extended make-up codes for run lengths > 1728 (T.4 Table 3b/T.4, T.6 Table 3/T.6).
let common_makeup : FixedArray[(Int, Int, Int)] = [
  (1792, 11, 0b00000001000),
  (1856, 11, 0b00000001100),
  (1920, 11, 0b00000001101),
  (1984, 12, 0b000000010010),
  (2048, 12, 0b000000010011),
  (2112, 12, 0b000000010100),
  (2176, 12, 0b000000010101),
  (2240, 12, 0b000000010110),
  (2304, 12, 0b000000010111),
  (2368, 12, 0b000000011100),
  (2432, 12, 0b000000011101),
  (2496, 12, 0b000000011110),
  (2560, 12, 0b000000011111),
]

///|
/// Mode codes for 2D encoding (T.4 Table 4/T.4, T.6 Table 1/T.6).
let mode_codes : FixedArray[(Int, Int, Int)] = [
  (0, 4, 0b0001),
  (1, 3, 0b001),
  (2, 1, 0b1),
  (3, 3, 0b011),
  (4, 6, 0b000011),
  (5, 7, 0b0000011),
  (6, 3, 0b010),
  (7, 6, 0b000010),
  (8, 7, 0b0000010),
]
