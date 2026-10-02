// Port of `fancy-regex` 0.16.2 `src/parse_flags.rs`.

///|
/// Flag bit for case insensitive matching
pub const FLAG_CASEI : Int = 1

///|
/// Flag bit for multi-line mode
pub const FLAG_MULTI : Int = 2 // 1 << 1

///|
/// Flag bit for dot matches newline
pub const FLAG_DOTNL : Int = 4 // 1 << 2

///|
/// Flag bit for swapping greed
pub const FLAG_SWAP_GREED : Int = 8 // 1 << 3

///|
/// Flag bit for ignoring whitespace
pub const FLAG_IGNORE_SPACE : Int = 16 // 1 << 4

///|
/// Flag bit for unicode mode
pub const FLAG_UNICODE : Int = 32 // 1 << 5

///|
/// Flag bit for Oniguruma mode
pub const FLAG_ONIGURUMA_MODE : Int = 64 // 1 << 6
