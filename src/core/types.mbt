// rough.js 4.6.6 src/core.ts: Op, OpSet, Drawable, PathInfo.

///|
/// One drawing operation of an `OpSet`.
pub(all) enum Op {
  /// `move` to (x, y).
  Move(Double, Double)
  /// `lineTo` (x, y).
  LineTo(Double, Double)
  /// `bcurveTo`: cubic Bézier with control points (x1, y1), (x2, y2) ending
  /// at (x, y).
  BCurveTo(Double, Double, Double, Double, Double, Double)
} derive(Eq, Debug)

///|
/// The rough.js op name: `"move"`, `"lineTo"` or `"bcurveTo"`.
pub fn Op::name(self : Op) -> String {
  match self {
    Move(_, _) => "move"
    LineTo(_, _) => "lineTo"
    BCurveTo(_, _, _, _, _, _) => "bcurveTo"
  }
}

///|
/// The op's `data` array as in rough.js.
pub fn Op::data(self : Op) -> Array[Double] {
  match self {
    Move(x, y) | LineTo(x, y) => [x, y]
    BCurveTo(x1, y1, x2, y2, x, y) => [x1, y1, x2, y2, x, y]
  }
}

///|
/// How an `OpSet` is meant to be painted.
pub(all) enum OpSetType {
  /// The outline: stroke with `stroke` / `stroke_width`, no fill.
  Path
  /// A filled area (fill style `solid`): fill with `fill`, no stroke.
  FillPath
  /// Fill strokes (hachures, dots, ...): stroke with `fill`, width
  /// `fill_weight`.
  FillSketch
} derive(Eq, Debug)

///|
/// The rough.js name: `"path"`, `"fillPath"` or `"fillSketch"`.
pub fn OpSetType::name(self : OpSetType) -> String {
  match self {
    Path => "path"
    FillPath => "fillPath"
    FillSketch => "fillSketch"
  }
}

///|
/// A list of ops painted together.
pub(all) struct OpSet {
  kind : OpSetType
  ops : Array[Op]
} derive(Eq, Debug)

///|
/// The kind of shape a `Drawable` was generated from.
pub(all) enum Shape {
  Line
  Rectangle
  Ellipse
  Circle
  LinearPath
  Polygon
  Arc
  Curve
  Path
} derive(Eq, Debug)

///|
/// The rough.js name: `"line"`, `"rectangle"`, `"linearPath"`, ...
pub fn Shape::name(self : Shape) -> String {
  match self {
    Line => "line"
    Rectangle => "rectangle"
    Ellipse => "ellipse"
    Circle => "circle"
    LinearPath => "linearPath"
    Polygon => "polygon"
    Arc => "arc"
    Curve => "curve"
    Path => "path"
  }
}

///|
/// A generated shape: backend-independent op sets plus the options needed
/// to paint them.
pub struct Drawable {
  shape : Shape
  options : ResolvedOptions
  sets : Array[OpSet]
}

///|
/// `PathInfo`: one SVG path (`d` plus paint attributes), as returned by
/// `Generator::to_paths`.
pub(all) struct PathInfo {
  d : String
  stroke : String
  stroke_width : Double
  fill : String?
} derive(Eq, Debug)
