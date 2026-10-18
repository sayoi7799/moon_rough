// The point type shared by the ported algorithms (rough.js src/geometry.ts).

///|
/// A point, `[x, y]` in rough.js.
///
/// Points are mutable and compared by identity on purpose: hachure-fill
/// rotates the polygons it is given in place (and back), and later stages of
/// rough.js read those slightly perturbed coordinates. Sharing and copying
/// points exactly where the JavaScript code shares or copies its arrays keeps
/// the results bit-identical.
pub(all) struct Point {
  mut x : Double
  mut y : Double
} derive(Debug)

///|
pub fn Point::new(x : Double, y : Double) -> Point {
  { x, y, }
}

///|
/// A new point with the same coordinates (`[...p]` / `[p[0], p[1]]`).
pub fn Point::copy(self : Point) -> Point {
  { x: self.x, y: self.y, }
}

///|
/// `lineLength([p1, p2])`.
pub fn line_length(p1 : Point, p2 : Point) -> Double {
  let dx = p1.x - p2.x
  let dy = p1.y - p2.y
  // Math.pow(d, 2) is exactly d * d in V8 (fdlibm's pow special-cases y = 2).
  (dx * dx + dy * dy).sqrt()
}
