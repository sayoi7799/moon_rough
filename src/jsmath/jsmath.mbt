// The parts of JavaScript's numeric semantics that rough.js depends on,
// implemented so that every backend produces the same bits as Node.

///|
/// `Math.PI`.
pub const PI : Double = 3.141592653589793

///|
/// `Math.tan`. moonbitlang/core uses fdlibm on every backend but js.
pub fn tan(x : Double) -> Double {
  @math.tan(x)
}

///|
/// `Math.atan`.
pub fn atan(x : Double) -> Double {
  @math.atan(x)
}

///|
/// `Math.asin`.
pub fn asin(x : Double) -> Double {
  @math.asin(x)
}

///|
/// `Math.round`: rounds half-way cases towards +Infinity and keeps the sign
/// of zero (`Math.round(-0.4)` is `-0`).
pub fn round(x : Double) -> Double {
  let r = x.floor()
  let v = if x - r >= 0.5 { r + 1.0 } else { r }
  if v == 0.0 && x < 0.0 {
    -0.0
  } else {
    v
  }
}

///|
/// `Number.prototype.toString()` (radix 10): the shortest string that
/// round-trips, in JavaScript's notation (`1e+21`, `1e-7`, `-0` is `"0"`).
pub fn number_to_string(x : Double) -> String {
  x.to_string()
}

///|
/// `Number.prototype.toFixed(digits)`, exact as in the ECMAScript
/// specification: the decimal is computed from the exact binary value, ties
/// go to the larger magnitude, and numbers >= 1e21 use `number_to_string`.
/// `digits` is clamped to `[0, 100]` (JavaScript throws a RangeError
/// outside that range).
pub fn to_fixed(x : Double, digits : Int) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let f = if digits < 0 { 0 } else if digits > 100 { 100 } else { digits }
  let (sign, x) = if x < 0.0 { ("-", -x) } else { ("", x) }
  if x >= 1.0e21 {
    return sign + number_to_string(x)
  }
  // x = mantissa * 2^exponent exactly.
  let bits = x.reinterpret_as_uint64()
  let biased = ((bits >> 52) & 0x7ff).to_int()
  let fraction = bits & 0xF_FFFF_FFFF_FFFF
  let (mantissa, exponent) = if biased == 0 {
    (fraction, -1074)
  } else {
    (fraction | (1UL << 52), biased - 1075)
  }
  // n = round(x * 10^f), ties to the larger n.
  let scaled = @bigint.BigInt::from_uint64(mantissa) * pow10(f)
  let n = if exponent >= 0 {
    scaled.shl(exponent)
  } else {
    let q = scaled.shr(-exponent)
    let rem = scaled - q.shl(-exponent)
    if rem.shl(1).compare(@bigint.BigInt::from_int(1).shl(-exponent)) >= 0 {
      q + @bigint.BigInt::from_int(1)
    } else {
      q
    }
  }
  let m = n.to_string()
  if f == 0 {
    return sign + m
  }
  let buf = StringBuilder()
  buf.write_string(sign)
  let k = m.length()
  if k <= f {
    buf.write_string("0.")
    for _ in 0..<(f - k) {
      buf.write_char('0')
    }
    buf.write_string(m)
  } else {
    buf.write_view(m[:k - f])
    buf.write_char('.')
    buf.write_view(m[k - f:])
  }
  buf.to_string()
}

///|
fn pow10(n : Int) -> @bigint.BigInt {
  let ten = @bigint.BigInt::from_int(10)
  let mut r = @bigint.BigInt::from_int(1)
  for _ in 0..<n {
    r = r * ten
  }
  r
}

///|
/// `parseFloat` for the decimal literals path-data-parser's tokenizer
/// accepts (`[-+]?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?`), correctly rounded.
/// Like JavaScript, literals too large for a double give `Infinity`, and the
/// strings `toFixed` produces for non-finite numbers (`"NaN"`, `"Infinity"`,
/// `"-Infinity"`) parse back to those values.
pub fn parse_float(s : StringView) -> Double {
  if s == "NaN" {
    return @double.not_a_number
  }
  @string.parse_double(s) catch {
    _ if s.length() > 0 && s.unsafe_get(0) == '-' => @double.neg_infinity
    _ => @double.infinity
  }
}
