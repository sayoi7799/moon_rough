// Port of rough.js 4.6.6 src/generator.ts (RoughGenerator).

///|
/// Generates `Drawable`s: rough.js' `RoughGenerator` (`rough.generator()`).
pub struct Generator {
  /// The options used when a shape gets no options of its own. As in
  /// rough.js this is a single object, so its random number generator
  /// carries on from one such shape to the next.
  default_options : ResolvedOptions
}

///|
/// `rough.generator({ options })`. `source` replaces `Math.random()` (seed 0,
/// dot positions, hachure fallback); the default is
/// `RandomSource::default()`, a fixed-seed Park-Miller sequence.
pub fn Generator::new(
  options? : Options,
  source? : @random.RandomSource,
) -> Generator {
  let source = match source {
    Some(source) => source
    None => @random.RandomSource::default()
  }
  let defaults = default_options(source)
  let default_options = match options {
    Some(options) => ResolvedOptions::merge(defaults, options)
    None => defaults
  }
  { default_options, }
}

///|
/// `RoughGenerator.newSeed()`: a random seed in `[0, 2^31)` from the
/// generator's random source.
pub fn Generator::new_seed(self : Generator) -> Int {
  @random.new_seed(self.default_options.source)
}

///|
/// `_o(options)`: the defaults themselves when no options are given.
fn Generator::resolve(self : Generator, options : Options?) -> ResolvedOptions {
  match options {
    Some(options) => ResolvedOptions::merge(self.default_options, options)
    None => self.default_options
  }
}

///|
fn to_points(points : Array[(Double, Double)]) -> Array[Point] {
  points.map(fn(p) { Point::new(p.0, p.1) })
}

///|
/// A line from (x1, y1) to (x2, y2).
pub fn Generator::line(
  self : Generator,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  options? : Options,
) -> Drawable {
  let o = self.resolve(options)
  { shape: Line, sets: [line(x1, y1, x2, y2, o)], options: o, }
}

///|
/// A rectangle with top-left corner (x, y).
pub fn Generator::rectangle(
  self : Generator,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  options? : Options,
) -> Drawable {
  let o = self.resolve(options)
  let paths = []
  let outline = rectangle(x, y, width, height, o)
  if has_fill(o) {
    let points = rectangle_points(x, y, width, height)
    if o.fill_style == Solid {
      paths.push(solid_fill_polygon([points], o))
    } else {
      paths.push(pattern_fill_polygons([points], o))
    }
  }
  if o.stroke != "none" {
    paths.push(outline)
  }
  { shape: Rectangle, sets: paths, options: o, }
}

///|
/// An ellipse centered at (x, y).
pub fn Generator::ellipse(
  self : Generator,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  options? : Options,
) -> Drawable {
  let o = self.resolve(options)
  let paths = []
  let ellipse_params = generate_ellipse_params(width, height, o)
  let ellipse_response = ellipse_with_params(x, y, o, ellipse_params)
  if has_fill(o) {
    if o.fill_style == Solid {
      // A second, independent pass over the ellipse (more random numbers).
      let shape = ellipse_with_params(x, y, o, ellipse_params).opset
      paths.push({ kind: FillPath, ops: shape.ops, })
    } else {
      paths.push(pattern_fill_polygons([ellipse_response.estimated_points], o))
    }
  }
  if o.stroke != "none" {
    paths.push(ellipse_response.opset)
  }
  { shape: Ellipse, sets: paths, options: o, }
}

///|
/// A circle centered at (x, y).
pub fn Generator::circle(
  self : Generator,
  x : Double,
  y : Double,
  diameter : Double,
  options? : Options,
) -> Drawable {
  let ret = self.ellipse(x, y, diameter, diameter, options?)
  { ..ret, shape: Circle, }
}

///|
/// An open polyline through `points`.
pub fn Generator::linear_path(
  self : Generator,
  points : Array[(Double, Double)],
  options? : Options,
) -> Drawable {
  let o = self.resolve(options)
  {
    shape: LinearPath,
    sets: [linear_path(to_points(points), false, o)],
    options: o,
  }
}

///|
/// An arc of the ellipse centered at (x, y), from angle `start` to `stop`
/// (radians). `closed` draws the two radii and allows a fill.
pub fn Generator::arc(
  self : Generator,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  start : Double,
  stop : Double,
  closed? : Bool = false,
  options? : Options,
) -> Drawable {
  let o = self.resolve(options)
  let paths = []
  let outline = arc(x, y, width, height, start, stop, closed, true, o)
  if closed && has_fill(o) {
    if o.fill_style == Solid {
      let fill_options = { ..o, disable_multi_stroke: true, }
      let shape = arc(
        x, y, width, height, start, stop, true, false, fill_options,
      )
      paths.push({ kind: FillPath, ops: shape.ops, })
    } else {
      paths.push(pattern_fill_arc(x, y, width, height, start, stop, o))
    }
  }
  if o.stroke != "none" {
    paths.push(outline)
  }
  { shape: Arc, sets: paths, options: o, }
}

///|
/// A smooth curve through `points`.
pub fn Generator::curve(
  self : Generator,
  points : Array[(Double, Double)],
  options? : Options,
) -> Drawable {
  let points_list = if points.length() > 0 { [to_points(points)] } else { [] }
  self.curve_points(points_list, options)
}

///|
/// Several curves drawn as one shape (rough.js' `curve(Point[][])`).
pub fn Generator::curves(
  self : Generator,
  points_list : Array[Array[(Double, Double)]],
  options? : Options,
) -> Drawable {
  self.curve_points(points_list.map(to_points), options)
}

///|
fn Generator::curve_points(
  self : Generator,
  points_list : Array[Array[Point]],
  options : Options?,
) -> Drawable {
  let o = self.resolve(options)
  let paths = []
  let outline = curve(points_list, o)
  if has_fill(o) && o.fill != Some("none") {
    if o.fill_style == Solid {
      let fill_shape = curve(points_list, {
        ..o,
        disable_multi_stroke: true,
        roughness: if truthy(o.roughness) {
          o.roughness + o.fill_shape_roughness_gain
        } else {
          0.0
        },
      })
      paths.push({ kind: FillPath, ops: merged_shape(fill_shape.ops), })
    } else {
      let poly_points = []
      let distance = (1.0 + o.roughness) / 2.0
      for points in points_list {
        if points.length() < 3 {
          poly_points.append(points)
        } else if points.length() == 3 {
          let bezier = @curve.curve_to_bezier([
            points[0],
            points[0],
            points[1],
            points[2],
          ]) catch {
            _ => panic()
          }
          poly_points.append(
            @curve.points_on_bezier_curves(bezier, tolerance=10.0, distance~),
          )
        } else {
          let bezier = @curve.curve_to_bezier(points) catch { _ => panic() }
          poly_points.append(
            @curve.points_on_bezier_curves(bezier, tolerance=10.0, distance~),
          )
        }
      }
      if poly_points.length() > 0 {
        paths.push(pattern_fill_polygons([poly_points], o))
      }
    }
  }
  if o.stroke != "none" {
    paths.push(outline)
  }
  { shape: Curve, sets: paths, options: o, }
}

///|
/// A closed polygon through `points`.
pub fn Generator::polygon(
  self : Generator,
  points : Array[(Double, Double)],
  options? : Options,
) -> Drawable {
  let o = self.resolve(options)
  let points = to_points(points)
  let paths = []
  let outline = linear_path(points, true, o)
  if has_fill(o) {
    if o.fill_style == Solid {
      paths.push(solid_fill_polygon([points], o))
    } else {
      paths.push(pattern_fill_polygons([points], o))
    }
  }
  if o.stroke != "none" {
    paths.push(outline)
  }
  { shape: Polygon, sets: paths, options: o, }
}

///|
/// The shape described by SVG path data `d`. Raises on malformed data,
/// where rough.js throws (or never returns).
pub fn Generator::path(
  self : Generator,
  d : StringView,
  options? : Options,
) -> Drawable raise @path_data.PathError {
  let o = self.resolve(options)
  let paths = []
  if d.length() == 0 {
    return { shape: Path, sets: paths, options: o, }
  }
  let d = preprocess_path(d)
  let has_fill = has_fill(o) &&
    o.fill != Some("transparent") &&
    o.fill != Some("none")
  let has_stroke = o.stroke != "none"
  let simplified = match o.simplification {
    Some(s) => truthy(s) && s < 1.0
    None => false
  }
  let distance = if simplified {
    4.0 - 4.0 * js_or(o.simplification.unwrap_or(0.0), 1.0)
  } else {
    (1.0 + o.roughness) / 2.0
  }
  let sets = @curve.points_on_path(d, tolerance=1.0, distance~)
  let shape = svg_path(d, o)
  if has_fill {
    if o.fill_style == Solid {
      if sets.length() == 1 {
        let fill_shape = svg_path(d, {
          ..o,
          disable_multi_stroke: true,
          roughness: if truthy(o.roughness) {
            o.roughness + o.fill_shape_roughness_gain
          } else {
            0.0
          },
        })
        paths.push({ kind: FillPath, ops: merged_shape(fill_shape.ops), })
      } else {
        paths.push(solid_fill_polygon(sets, o))
      }
    } else {
      paths.push(pattern_fill_polygons(sets, o))
    }
  }
  if has_stroke {
    if simplified {
      for set in sets {
        paths.push(linear_path(set, false, o))
      }
    } else {
      paths.push(shape)
    }
  }
  { shape: Path, sets: paths, options: o, }
}

///|
/// The string clean-up `RoughGenerator.path` applies first:
/// `d.replace(/\n/g, ' ').replace(/(-\s)/g, '-')`, then the third replace
/// of the published bundle, `.replace("/(ss)/g", " ")` (a plain-string
/// replace of its first occurrence).
fn preprocess_path(d : StringView) -> String {
  let buf = StringBuilder()
  let n = d.length()
  let mut i = 0
  while i < n {
    let c = d.unsafe_get(i)
    if c == '-' && i + 1 < n && is_js_whitespace(d.unsafe_get(i + 1)) {
      // `-` followed by any \s (a \n has become a space by now) is `-`.
      buf.write_char('-')
      i += 2
    } else {
      buf.write_char(if c == '\n' { ' ' } else { c.to_int().unsafe_to_char() })
      i += 1
    }
  }
  buf.to_string().replace(old="/(ss)/g", new=" ")
}

///|
/// JavaScript's `\s` (WhiteSpace and LineTerminator), one UTF-16 unit.
fn is_js_whitespace(c : UInt16) -> Bool {
  match c.to_int() {
    0x09
    | 0x0a
    | 0x0b
    | 0x0c
    | 0x0d
    | 0x20
    | 0xa0
    | 0x1680
    | 0x2028
    | 0x2029
    | 0x202f
    | 0x205f
    | 0x3000
    | 0xfeff => true
    c => c >= 0x2000 && c <= 0x200a
  }
}

///|
/// `_mergedShape`: drops every `move` but the first op.
fn merged_shape(input : Array[Op]) -> Array[Op] {
  let out = []
  for i, d in input {
    if i == 0 || !(d is Move(_, _)) {
      out.push(d)
    }
  }
  out
}

///|
/// `opsToPath(drawing, fixedDecimals)`: SVG path data for an op set. With
/// `fixed_decimals`, numbers are rounded like `+n.toFixed(fixed_decimals)`.
pub fn Generator::ops_to_path(
  self : Generator,
  drawing : OpSet,
  fixed_decimals? : Int,
) -> String {
  ignore(self)
  ops_to_path(drawing, fixed_decimals?)
}

///|
/// `opsToPath` (see `Generator::ops_to_path`).
pub fn ops_to_path(drawing : OpSet, fixed_decimals? : Int) -> String {
  let fmt = match fixed_decimals {
    Some(digits) if digits >= 0 =>
      fn(x : Double) {
        @jsmath.number_to_string(
          @jsmath.parse_float(@jsmath.to_fixed(x, digits)),
        )
      }
    _ => @jsmath.number_to_string
  }
  let path = StringBuilder()
  for item in drawing.ops {
    match item {
      Move(x, y) => path.write_string("M\{fmt(x)} \{fmt(y)} ")
      BCurveTo(x1, y1, x2, y2, x, y) =>
        path.write_string(
          "C\{fmt(x1)} \{fmt(y1)}, \{fmt(x2)} \{fmt(y2)}, \{fmt(x)} \{fmt(y)} ",
        )
      LineTo(x, y) => path.write_string("L\{fmt(x)} \{fmt(y)} ")
    }
  }
  path.to_string().trim().to_owned()
}

///|
/// `toPaths(drawable)`: one `PathInfo` per op set.
pub fn Generator::to_paths(
  self : Generator,
  drawable : Drawable,
) -> Array[PathInfo] {
  ignore(self)
  let o = drawable.options
  drawable.sets.map(fn(drawing) {
    match drawing.kind {
      Path =>
        {
          d: ops_to_path(drawing),
          stroke: o.stroke,
          stroke_width: o.stroke_width,
          fill: Some("none"),
        }
      FillPath =>
        {
          d: ops_to_path(drawing),
          stroke: "none",
          stroke_width: 0.0,
          fill: Some(o.fill.unwrap_or("none")),
        }
      FillSketch => fill_sketch(drawing, o)
    }
  })
}

///|
fn fill_sketch(drawing : OpSet, o : ResolvedOptions) -> PathInfo {
  let mut fweight = o.fill_weight
  if fweight < 0.0 {
    fweight = o.stroke_width / 2.0
  }
  {
    d: ops_to_path(drawing),
    stroke: o.fill.unwrap_or("none"),
    stroke_width: fweight,
    fill: Some("none"),
  }
}
