// On wasm and wasm-gc, moonbitlang/core already implements these functions
// with fdlibm in MoonBit, and they agree bit for bit with V8 (see the fixture
// tests). The js and native backends use fdlibm.mbt instead.

///|
/// Sine, bit-identical to JavaScript's `Math.sin`.
pub fn sin(x : Double) -> Double {
  @math.sin(x)
}

///|
/// Cosine, bit-identical to JavaScript's `Math.cos`.
pub fn cos(x : Double) -> Double {
  @math.cos(x)
}

///|
/// Tangent, bit-identical to JavaScript's `Math.tan`.
pub fn tan(x : Double) -> Double {
  @math.tan(x)
}

///|
/// Arc sine, bit-identical to JavaScript's `Math.asin`.
pub fn asin(x : Double) -> Double {
  @math.asin(x)
}

///|
/// Arc tangent, bit-identical to JavaScript's `Math.atan`.
pub fn atan(x : Double) -> Double {
  @math.atan(x)
}
