// On js, wasm and wasm-gc, moonbitlang/core's sine and cosine already agree
// bit for bit with V8's (JavaScript's Math itself on js, fdlibm elsewhere).

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
