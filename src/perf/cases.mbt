// The inputs of the benchmarks: scripts/bench_cases.mjs in MoonBit.
//
// Both generate the same shapes and paths from the Park-Miller sequence of
// rough.js' Random, with the same arithmetic in the same order; the checksum
// test compares what this package makes of them with what rough.js 4.6.6
// makes of the JavaScript ones.

///|
pub struct Rng {
  priv mut state : Int32
}

///|
pub fn Rng::new(seed : Int32) -> Rng {
  { state: seed, }
}

///|
/// The next number in [0, 1), as `new Random(seed).next()` of rough.js.
pub fn Rng::next(self : Rng) -> Double {
  self.state = 48271 * self.state
  (self.state & 0x7fffffff).to_double() / 2147483648.0
}

///|
/// 0 .. 500 with two decimals: a coordinate.
fn coordinate(r : Rng) -> Double {
  (r.next() * 50000.0).floor() / 100.0
}

///|
/// 10 .. 310 with two decimals: a width, height or diameter.
fn size(r : Rng) -> Double {
  10.0 + (r.next() * 30000.0).floor() / 100.0
}

///|
/// One shape and its options, the arguments of the shape method of rough.js.
pub struct Case {
  shape : String
  nums : Array[Double]
  points : Array[(Double, Double)]
  d : String
  options : @core.Options
}

///|
fn random_points(r : Rng, minimum : Int32) -> Array[(Double, Double)] {
  let count = minimum + (r.next() * 6.0).floor().to_int()
  let points = []
  for _ in 0..<count {
    let x = coordinate(r)
    let y = coordinate(r)
    points.push((x, y))
  }
  points
}

///|
fn random_path(r : Rng) -> String {
  let segments = 2 + (r.next() * 4.0).floor().to_int()
  let x = coordinate(r)
  let y = coordinate(r)
  let buf = StringBuilder()
  buf.write_string("M \{x} \{y}")
  for _ in 0..<segments {
    match (r.next() * 3.0).floor().to_int() {
      0 => {
        let x = coordinate(r)
        let y = coordinate(r)
        buf.write_string(" L \{x} \{y}")
      }
      1 => {
        let a = coordinate(r)
        let b = coordinate(r)
        let c = coordinate(r)
        let d = coordinate(r)
        let e = coordinate(r)
        let f = coordinate(r)
        buf.write_string(" C \{a} \{b} \{c} \{d} \{e} \{f}")
      }
      _ => {
        let a = coordinate(r)
        let b = coordinate(r)
        let c = coordinate(r)
        let d = coordinate(r)
        buf.write_string(" Q \{a} \{b} \{c} \{d}")
      }
    }
  }
  buf.write_string(" Z")
  buf.to_string()
}

///|
let fill_styles : Array[@core.FillStyle] = [
  Hachure,
  Solid,
  Zigzag,
  CrossHatch,
  Dashed,
  ZigzagLine,
]

///|
/// One random shape. With `dots`, every shape gets the dots fill; otherwise
/// each one gets no fill or one of six fill styles. `fixed_digits` sets
/// fixedDecimalPlaceDigits on every shape.
pub fn random_case(r : Rng, dots : Bool, fixed_digits : Int32?) -> Case {
  let kind = (r.next() * 9.0).floor().to_int()
  let mut shape = ""
  let mut nums : Array[Double] = []
  let mut points = []
  let mut d = ""
  match kind {
    0 => {
      shape = "line"
      let x1 = coordinate(r)
      let y1 = coordinate(r)
      let x2 = coordinate(r)
      let y2 = coordinate(r)
      nums = [x1, y1, x2, y2]
    }
    1 | 2 => {
      shape = if kind == 1 { "rectangle" } else { "ellipse" }
      let x = coordinate(r)
      let y = coordinate(r)
      let w = size(r)
      let h = size(r)
      nums = [x, y, w, h]
    }
    3 => {
      shape = "circle"
      let x = coordinate(r)
      let y = coordinate(r)
      let diameter = size(r)
      nums = [x, y, diameter]
    }
    4 => {
      shape = "linearPath"
      points = random_points(r, 2)
    }
    5 => {
      shape = "polygon"
      points = random_points(r, 3)
    }
    6 => {
      shape = "arc"
      let x = coordinate(r)
      let y = coordinate(r)
      let w = size(r)
      let h = size(r)
      let start = r.next() * 2.0 * @jsmath.PI
      let stop = start + 0.3 + r.next() * 5.0
      let closed = if r.next() < 0.6 { 1.0 } else { 0.0 }
      nums = [x, y, w, h, start, stop, closed]
    }
    7 => {
      shape = "curve"
      points = random_points(r, 3)
    }
    _ => {
      shape = "path"
      d = random_path(r)
    }
  }
  let seed = 1 + (r.next() * 1000000.0).floor().to_int()
  let roughness = (r.next() * 300.0).floor() / 100.0
  let bowing = (r.next() * 800.0).floor() / 100.0
  let hachure_angle = (r.next() * 3600.0).floor() / 10.0 - 180.0
  let hachure_gap = 4.0 + (r.next() * 160.0).floor() / 10.0
  let stroke_width = 0.5 + (r.next() * 40.0).floor() / 10.0
  let mut fill : String? = None
  let mut fill_style : @core.FillStyle? = None
  if dots {
    fill = Some("#e76f51")
    fill_style = Some(Dots)
  } else {
    let style = (r.next() * 7.0).floor().to_int()
    if style > 0 {
      fill = Some("#e76f51")
      fill_style = Some(fill_styles[style - 1])
    }
  }
  let options = @core.Options::new(
    seed~,
    roughness~,
    bowing~,
    hachure_angle~,
    hachure_gap~,
    stroke_width~,
    stroke="#1d3557",
    fill?,
    fill_style?,
    fixed_decimal_place_digits?=fixed_digits,
  )
  { shape, nums, points, d, options, }
}

///|
pub fn random_cases(
  count : Int32,
  seed : Int32,
  dots~ : Bool = false,
  fixed_digits? : Int32,
) -> Array[Case] {
  let r = Rng::new(seed)
  Array::makei(count, fn(_) { random_case(r, dots, fixed_digits) })
}

///|
/// Calls the shape method of the generator for a case.
pub fn Case::generate(self : Case, g : @core.Generator) -> @core.Drawable {
  let n = self.nums
  let options = self.options
  match self.shape {
    "line" => g.line(n[0], n[1], n[2], n[3], options~)
    "rectangle" => g.rectangle(n[0], n[1], n[2], n[3], options~)
    "ellipse" => g.ellipse(n[0], n[1], n[2], n[3], options~)
    "circle" => g.circle(n[0], n[1], n[2], options~)
    "linearPath" => g.linear_path(self.points, options~)
    "polygon" => g.polygon(self.points, options~)
    "curve" => g.curve(self.points, options~)
    "arc" =>
      g.arc(n[0], n[1], n[2], n[3], n[4], n[5], closed=n[6] == 1.0, options~)
    _ =>
      g.path(self.d, options~) catch {
        _ => abort("the path of the case is not valid")
      }
  }
}

///|
/// A complex SVG path of `segments` segments: absolute and relative lines,
/// horizontal and vertical lines, cubic and quadratic curves with their
/// smooth forms, elliptical arcs and several closed subpaths.
pub fn complex_path(segments : Int32, seed : Int32) -> String {
  let r = Rng::new(seed)
  let absolute = fn() { 100.0 + (r.next() * 30000.0).floor() / 100.0 }
  let relative = fn() { (r.next() * 8000.0).floor() / 100.0 - 40.0 }
  let radius = fn() { 5.0 + (r.next() * 3000.0).floor() / 100.0 }
  let buf = StringBuilder()
  let x = absolute()
  let y = absolute()
  buf.write_string("M \{x} \{y}")
  for _ in 0..<segments {
    match (r.next() * 12.0).floor().to_int() {
      0 => {
        let a = relative()
        let b = relative()
        buf.write_string(" l \{a} \{b}")
      }
      1 => {
        let a = relative()
        buf.write_string(" h \{a}")
      }
      2 => {
        let a = relative()
        buf.write_string(" v \{a}")
      }
      3 => {
        let a = relative()
        let b = relative()
        let c = relative()
        let d = relative()
        let e = relative()
        let f = relative()
        buf.write_string(" c \{a} \{b} \{c} \{d} \{e} \{f}")
      }
      4 => {
        let a = relative()
        let b = relative()
        let c = relative()
        let d = relative()
        buf.write_string(" s \{a} \{b} \{c} \{d}")
      }
      5 => {
        let a = relative()
        let b = relative()
        let c = relative()
        let d = relative()
        buf.write_string(" q \{a} \{b} \{c} \{d}")
      }
      6 => {
        let a = relative()
        let b = relative()
        buf.write_string(" t \{a} \{b}")
      }
      7 => {
        let rx = radius()
        let ry = radius()
        let rotation = (r.next() * 90.0).floor()
        let large = if r.next() < 0.5 { 1 } else { 0 }
        let sweep = if r.next() < 0.5 { 1 } else { 0 }
        let a = relative()
        let b = relative()
        buf.write_string(
          " a \{rx} \{ry} \{rotation} \{large} \{sweep} \{a} \{b}",
        )
      }
      8 => {
        let a = absolute()
        let b = absolute()
        buf.write_string(" L \{a} \{b}")
      }
      9 => {
        let a = absolute()
        let b = absolute()
        let c = absolute()
        let d = absolute()
        let e = absolute()
        let f = absolute()
        buf.write_string(" C \{a} \{b} \{c} \{d} \{e} \{f}")
      }
      10 => {
        let a = absolute()
        let b = absolute()
        let c = absolute()
        let d = absolute()
        buf.write_string(" Q \{a} \{b} \{c} \{d}")
      }
      _ => {
        let a = relative()
        let b = relative()
        buf.write_string(" z m \{a} \{b}")
      }
    }
  }
  buf.write_string(" z")
  buf.to_string()
}

///|
/// What the checksum of the benchmark inputs consists of.
pub struct Checksum {
  sets : Int32
  ops : Int32
  sum : Double
}

///|
/// The numbers of the op sets of `drawables`, summed in order, with counts.
pub fn checksum(drawables : Array[@core.Drawable]) -> Checksum {
  let mut sets = 0
  let mut ops = 0
  let mut sum = 0.0
  for drawable in drawables {
    for set in drawable.sets {
      sets += 1
      for op in set.ops {
        ops += 1
        for x in op.data() {
          sum += x
        }
      }
    }
  }
  { sets, ops, sum, }
}

///|
/// The sizes and seeds of the inputs; scripts/gen_fixtures.mjs has the same.
pub const SHAPES : Int32 = 10000

///|
pub const SHAPE_SEED : Int32 = 1

///|
pub const DOTS : Int32 = 500

///|
pub const DOTS_SEED : Int32 = 2

///|
pub const SEGMENTS : Int32 = 300

///|
pub const PATH_SEED : Int32 = 11
