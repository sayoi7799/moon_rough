// Helpers shared by the fixture-driven tests: decoding the bit-exact doubles
// written by scripts/gen_fixtures.mjs and comparing them with a tolerance.

///|
/// Relative tolerance for coordinates: `|actual - expected| <= TOLERANCE *
/// max(1, |expected|)`. See README, "Floating-point comparison".
pub const TOLERANCE : Double = 1.0e-9

///|
/// Decodes 16 hex digits (an IEEE-754 bit pattern) into a double.
pub fn hex_to_double(s : StringView) -> Double {
  guard s.length() == 16 else { abort("bad hex double: \{s}") }
  let mut bits : UInt64 = 0
  for i in 0..<16 {
    let c = s.unsafe_get(i).to_int()
    let digit = if c >= '0' && c <= '9' {
      c - '0'
    } else if c >= 'a' && c <= 'f' {
      c - 'a' + 10
    } else {
      abort("bad hex digit in \{s}")
    }
    bits = (bits << 4) | digit.to_uint64()
  }
  bits.reinterpret_as_double()
}

///|
/// Decodes a space separated list of hex doubles; the empty string is `[]`.
pub fn hex_list(s : StringView) -> Array[Double] {
  if s.length() == 0 {
    return []
  }
  s.split(" ").map(hex_to_double).to_array()
}

///|
/// Splits a fixture entry on `|`.
pub fn fields(s : String) -> Array[StringView] {
  s.split("|").to_array()
}

///|
/// Exact equality that also treats two NaNs as equal.
pub fn same(a : Double, b : Double) -> Bool {
  a == b || (a.is_nan() && b.is_nan())
}

///|
/// Running statistics of the numeric differences seen by one test suite.
pub struct ErrorStats {
  name : String
  mut compared : Int32
  mut inexact : Int32
  mut max_abs : Double
  mut max_rel : Double
}

///|
pub fn ErrorStats::new(name : String) -> ErrorStats {
  { name, compared: 0, inexact: 0, max_abs: 0.0, max_rel: 0.0, }
}

///|
/// Records one comparison; returns whether it is within `TOLERANCE`.
pub fn ErrorStats::record(
  self : ErrorStats,
  actual : Double,
  expected : Double,
) -> Bool {
  self.compared += 1
  if same(actual, expected) {
    return true
  }
  self.inexact += 1
  let diff = (actual - expected).abs()
  if diff.is_nan() {
    self.max_abs = @double.infinity
    self.max_rel = @double.infinity
    return false
  }
  let scale = if expected.abs() > 1.0 { expected.abs() } else { 1.0 }
  if diff > self.max_abs {
    self.max_abs = diff
  }
  if diff / scale > self.max_rel {
    self.max_rel = diff / scale
  }
  diff <= TOLERANCE * scale
}

///|
/// One line summary, e.g. for the error report in the README.
pub fn ErrorStats::summary(self : ErrorStats) -> String {
  "[error report] \{self.name}: \{self.compared} values, \{self.inexact} not bit-identical, max abs error \{self.max_abs}, max rel error \{self.max_rel}"
}
