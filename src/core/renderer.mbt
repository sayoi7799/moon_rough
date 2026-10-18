// Port of rough.js 4.6.6 src/renderer.ts.
//
// Evaluation order: rough.js draws its random numbers inside expressions and
// argument lists, which JavaScript evaluates left to right. Here every call
// that consumes a random number is a statement of its own, in the order the
// JavaScript code evaluates them; drawing one number more, less or earlier
// would shift every later coordinate.

///|
using @geometry {type Point}

///|
priv struct EllipseParams {
  increment : Double
  rx : Double
  ry : Double
}

///|
priv struct EllipseResult {
  estimated_points : Array[Point]
  opset : OpSet
}

///|
fn line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  o : ResolvedOptions,
) -> OpSet {
  { kind: Path, ops: double_line(x1, y1, x2, y2, o), }
}

///|
fn linear_path(
  points : Array[Point],
  close : Bool,
  o : ResolvedOptions,
) -> OpSet {
  let len = points.length()
  if len > 2 {
    let ops = []
    for i in 0..<(len - 1) {
      ops.append(
        double_line(
          points[i].x,
          points[i].y,
          points[i + 1].x,
          points[i + 1].y,
          o,
        ),
      )
    }
    if close {
      ops.append(
        double_line(
          points[len - 1].x,
          points[len - 1].y,
          points[0].x,
          points[0].y,
          o,
        ),
      )
    }
    { kind: Path, ops, }
  } else if len == 2 {
    line(points[0].x, points[0].y, points[1].x, points[1].y, o)
  } else {
    { kind: Path, ops: [], }
  }
}

///|
fn polygon(points : Array[Point], o : ResolvedOptions) -> OpSet {
  linear_path(points, true, o)
}

///|
fn rectangle_points(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Array[Point] {
  [
    Point::new(x, y),
    Point::new(x + width, y),
    Point::new(x + width, y + height),
    Point::new(x, y + height),
  ]
}

///|
fn rectangle(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  o : ResolvedOptions,
) -> OpSet {
  polygon(rectangle_points(x, y, width, height), o)
}

///|
fn curve(points_list : Array[Array[Point]], o : ResolvedOptions) -> OpSet {
  if points_list.length() == 0 {
    return { kind: Path, ops: [], }
  }
  let o1 = curve_with_offset(points_list[0], 1.0 * (1.0 + o.roughness * 0.2), o)
  let o2 = if o.disable_multi_stroke {
    []
  } else {
    curve_with_offset(
      points_list[0],
      1.5 * (1.0 + o.roughness * 0.22),
      clone_options_alter_seed(o),
    )
  }
  for i in 1..<points_list.length() {
    let points = points_list[i]
    if points.length() > 0 {
      let underlay = curve_with_offset(
        points,
        1.0 * (1.0 + o.roughness * 0.2),
        o,
      )
      let overlay = if o.disable_multi_stroke {
        []
      } else {
        curve_with_offset(
          points,
          1.5 * (1.0 + o.roughness * 0.22),
          clone_options_alter_seed(o),
        )
      }
      for item in underlay {
        if !(item is Move(_, _)) {
          o1.push(item)
        }
      }
      for item in overlay {
        if !(item is Move(_, _)) {
          o2.push(item)
        }
      }
    }
  }
  { kind: Path, ops: [..o1, ..o2], }
}

///|
fn ellipse(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  o : ResolvedOptions,
) -> OpSet {
  let params = generate_ellipse_params(width, height, o)
  ellipse_with_params(x, y, o, params).opset
}

///|
fn generate_ellipse_params(
  width : Double,
  height : Double,
  o : ResolvedOptions,
) -> EllipseParams {
  let hw = width / 2.0
  let hh = height / 2.0
  let psq = (@jsmath.PI * 2.0 * ((hw * hw + hh * hh) / 2.0).sqrt()).sqrt()
  let step_count = @jsmath.max(
    o.curve_step_count,
    o.curve_step_count / (200.0 : Double).sqrt() * psq,
  ).ceil()
  let increment = @jsmath.PI * 2.0 / step_count
  let mut rx = (width / 2.0).abs()
  let mut ry = (height / 2.0).abs()
  let curve_fit_randomness = 1.0 - o.curve_fitting
  rx += offset_opt(rx * curve_fit_randomness, o)
  ry += offset_opt(ry * curve_fit_randomness, o)
  { increment, rx, ry, }
}

///|
fn ellipse_with_params(
  x : Double,
  y : Double,
  o : ResolvedOptions,
  params : EllipseParams,
) -> EllipseResult {
  // `increment * _offset(0.1, _offset(0.4, 1, o), o)`: inner call first.
  let inner = offset(0.4, 1.0, o)
  let overlap = params.increment * offset(0.1, inner, o)
  let (ap1, cp1) = compute_ellipse_points(
    params.increment,
    x,
    y,
    params.rx,
    params.ry,
    1.0,
    overlap,
    o,
  )
  let o1 = curve_ops(ap1, o)
  if !o.disable_multi_stroke && o.roughness != 0.0 {
    let (ap2, _) = compute_ellipse_points(
      params.increment,
      x,
      y,
      params.rx,
      params.ry,
      1.5,
      0.0,
      o,
    )
    o1.append(curve_ops(ap2, o))
  }
  { estimated_points: cp1, opset: { kind: Path, ops: o1, }, }
}

///|
fn arc(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  start : Double,
  stop : Double,
  closed : Bool,
  rough_closure : Bool,
  o : ResolvedOptions,
) -> OpSet {
  let cx = x
  let cy = y
  let mut rx = (width / 2.0).abs()
  let mut ry = (height / 2.0).abs()
  rx += offset_opt(rx * 0.01, o)
  ry += offset_opt(ry * 0.01, o)
  let (strt, stp) = normalize_arc_angles(start, stop)
  let ellipse_inc = @jsmath.PI * 2.0 / o.curve_step_count
  let arc_inc = @jsmath.min(ellipse_inc / 2.0, (stp - strt) / 2.0)
  let ops = arc_ops(arc_inc, cx, cy, rx, ry, strt, stp, 1.0, o)
  if !o.disable_multi_stroke {
    let o2 = arc_ops(arc_inc, cx, cy, rx, ry, strt, stp, 1.5, o)
    ops.append(o2)
  }
  if closed {
    if rough_closure {
      ops.append(
        double_line(
          cx,
          cy,
          cx + rx * @jsmath.cos(strt),
          cy + ry * @jsmath.sin(strt),
          o,
        ),
      )
      ops.append(
        double_line(
          cx,
          cy,
          cx + rx * @jsmath.cos(stp),
          cy + ry * @jsmath.sin(stp),
          o,
        ),
      )
    } else {
      ops.push(LineTo(cx, cy))
      ops.push(LineTo(cx + rx * @jsmath.cos(strt), cy + ry * @jsmath.sin(strt)))
    }
  }
  { kind: Path, ops, }
}

///|
/// The start / stop normalization shared by `arc` and `patternFillArc`.
fn normalize_arc_angles(start : Double, stop : Double) -> (Double, Double) {
  let mut strt = start
  let mut stp = stop
  while strt < 0.0 {
    strt += @jsmath.PI * 2.0
    stp += @jsmath.PI * 2.0
  }
  if stp - strt > @jsmath.PI * 2.0 {
    strt = 0.0
    stp = @jsmath.PI * 2.0
  }
  (strt, stp)
}

///|
fn svg_path(
  path : StringView,
  o : ResolvedOptions,
) -> OpSet raise @path_data.PathError {
  let segments = @path_data.normalize(
    @path_data.absolutize(@path_data.parse_path(path)),
  )
  let ops = []
  let mut first = (0.0, 0.0)
  let mut current = (0.0, 0.0)
  for segment in segments {
    let data = segment.data
    match segment.key {
      'M' => {
        current = (data[0], data[1])
        first = (data[0], data[1])
      }
      'L' => {
        ops.append(double_line(current.0, current.1, data[0], data[1], o))
        current = (data[0], data[1])
      }
      'C' => {
        let x1 = data[0]
        let y1 = data[1]
        let x2 = data[2]
        let y2 = data[3]
        let x = data[4]
        let y = data[5]
        ops.append(bezier_to(x1, y1, x2, y2, x, y, current, o))
        current = (x, y)
      }
      'Z' => {
        ops.append(double_line(current.0, current.1, first.0, first.1, o))
        current = (first.0, first.1)
      }
      _ => ()
    }
  }
  { kind: Path, ops, }
}

// Fills

///|
fn solid_fill_polygon(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let ops = []
  for points in polygon_list {
    if points.length() > 0 {
      let offset = js_or(o.max_randomness_offset, 0.0)
      let len = points.length()
      if len > 2 {
        let mx = points[0].x + offset_opt(offset, o)
        let my = points[0].y + offset_opt(offset, o)
        ops.push(Move(mx, my))
        for i in 1..<len {
          let lx = points[i].x + offset_opt(offset, o)
          let ly = points[i].y + offset_opt(offset, o)
          ops.push(LineTo(lx, ly))
        }
      }
    }
  }
  { kind: FillPath, ops, }
}

///|
fn pattern_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  fill_polygons(polygon_list, o)
}

///|
fn pattern_fill_arc(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  start : Double,
  stop : Double,
  o : ResolvedOptions,
) -> OpSet {
  let cx = x
  let cy = y
  let mut rx = (width / 2.0).abs()
  let mut ry = (height / 2.0).abs()
  rx += offset_opt(rx * 0.01, o)
  ry += offset_opt(ry * 0.01, o)
  let (strt, stp) = normalize_arc_angles(start, stop)
  let increment = (stp - strt) / o.curve_step_count
  let points = []
  // rough.js loops forever when the increment is zero or negative.
  if increment.is_nan() || increment > 0.0 {
    for angle = strt; angle <= stp; angle = angle + increment {
      points.push(
        Point::new(cx + rx * @jsmath.cos(angle), cy + ry * @jsmath.sin(angle)),
      )
    }
  }
  points.push(
    Point::new(cx + rx * @jsmath.cos(stp), cy + ry * @jsmath.sin(stp)),
  )
  points.push(Point::new(cx, cy))
  pattern_fill_polygons([points], o)
}

///|
/// `doubleLineOps` of the filler helper: a double line using
/// `disable_multi_stroke_fill`.
fn double_line_fill_ops(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  o : ResolvedOptions,
) -> Array[Op] {
  double_line(x1, y1, x2, y2, o, filling=true)
}

// Private helpers

///|
/// JavaScript `x || fallback` for a number.
fn js_or(x : Double, fallback : Double) -> Double {
  if truthy(x) {
    x
  } else {
    fallback
  }
}

///|
/// `cloneOptionsAlterSeed`: a copy without randomizer, seeded with seed + 1.
fn clone_options_alter_seed(ops : ResolvedOptions) -> ResolvedOptions {
  {
    ..ops,
    randomizer: None,
    seed: if ops.seed != 0 {
      ops.seed + 1
    } else {
      ops.seed
    },
  }
}

///|
/// `random(ops)`: creates the options' randomizer on first use.
fn random(ops : ResolvedOptions) -> Double {
  match ops.randomizer {
    Some(r) => r.next()
    None => {
      let r = @random.Random::new(ops.seed, source=ops.source)
      ops.randomizer = Some(r)
      r.next()
    }
  }
}

///|
fn offset(
  min : Double,
  max : Double,
  ops : ResolvedOptions,
  roughness_gain? : Double = 1.0,
) -> Double {
  let r = random(ops)
  ops.roughness * roughness_gain * (r * (max - min) + min)
}

///|
fn offset_opt(
  x : Double,
  ops : ResolvedOptions,
  roughness_gain? : Double = 1.0,
) -> Double {
  offset(-x, x, ops, roughness_gain~)
}

///|
fn double_line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  o : ResolvedOptions,
  filling? : Bool = false,
) -> Array[Op] {
  let single_stroke = if filling {
    o.disable_multi_stroke_fill
  } else {
    o.disable_multi_stroke
  }
  let o1 = line_ops(x1, y1, x2, y2, o, true, false)
  if single_stroke {
    return o1
  }
  let o2 = line_ops(x1, y1, x2, y2, o, true, true)
  [..o1, ..o2]
}

///|
fn line_ops(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  o : ResolvedOptions,
  with_move : Bool,
  overlay : Bool,
) -> Array[Op] {
  let dx = x1 - x2
  let dy = y1 - y2
  let length_sq = dx * dx + dy * dy
  let length = length_sq.sqrt()
  let roughness_gain = if length < 200.0 {
    1.0
  } else if length > 500.0 {
    0.4
  } else {
    -0.0016668 * length + 1.233334
  }
  let mut offset = js_or(o.max_randomness_offset, 0.0)
  if offset * offset * 100.0 > length_sq {
    offset = length / 10.0
  }
  let half_offset = offset / 2.0
  let diverge_point = 0.2 + random(o) * 0.2
  let mut mid_disp_x = o.bowing * o.max_randomness_offset * (y2 - y1) / 200.0
  let mut mid_disp_y = o.bowing * o.max_randomness_offset * (x1 - x2) / 200.0
  mid_disp_x = offset_opt(mid_disp_x, o, roughness_gain~)
  mid_disp_y = offset_opt(mid_disp_y, o, roughness_gain~)
  let ops = []
  let random_half = fn() { offset_opt(half_offset, o, roughness_gain~) }
  let random_full = fn() { offset_opt(offset, o, roughness_gain~) }
  let preserve_vertices = o.preserve_vertices
  if with_move {
    if overlay {
      let mx = x1 + (if preserve_vertices { 0.0 } else { random_half() })
      let my = y1 + (if preserve_vertices { 0.0 } else { random_half() })
      ops.push(Move(mx, my))
    } else {
      let mx = x1 + (if preserve_vertices { 0.0 } else { random_full() })
      let my = y1 + (if preserve_vertices { 0.0 } else { random_full() })
      ops.push(Move(mx, my))
    }
  }
  let rnd = if overlay { random_half } else { random_full }
  let c1x = mid_disp_x + x1 + (x2 - x1) * diverge_point + rnd()
  let c1y = mid_disp_y + y1 + (y2 - y1) * diverge_point + rnd()
  let c2x = mid_disp_x + x1 + 2.0 * (x2 - x1) * diverge_point + rnd()
  let c2y = mid_disp_y + y1 + 2.0 * (y2 - y1) * diverge_point + rnd()
  let ex = x2 + (if preserve_vertices { 0.0 } else { rnd() })
  let ey = y2 + (if preserve_vertices { 0.0 } else { rnd() })
  ops.push(BCurveTo(c1x, c1y, c2x, c2y, ex, ey))
  ops
}

///|
fn curve_with_offset(
  points : Array[Point],
  offset : Double,
  o : ResolvedOptions,
) -> Array[Op] {
  if points.length() == 0 {
    return []
  }
  let ps = []
  // The first point twice, then every point, the last one twice.
  for _ in 0..<2 {
    let x = points[0].x + offset_opt(offset, o)
    let y = points[0].y + offset_opt(offset, o)
    ps.push(Point::new(x, y))
  }
  for i in 1..<points.length() {
    let x = points[i].x + offset_opt(offset, o)
    let y = points[i].y + offset_opt(offset, o)
    ps.push(Point::new(x, y))
    if i == points.length() - 1 {
      let x = points[i].x + offset_opt(offset, o)
      let y = points[i].y + offset_opt(offset, o)
      ps.push(Point::new(x, y))
    }
  }
  curve_ops(ps, o)
}

///|
/// `_curve(points, null, o)`. (Every caller in rough.js 4.6.6 passes a null
/// `closePoint`, so that branch is not ported.)
fn curve_ops(points : Array[Point], o : ResolvedOptions) -> Array[Op] {
  let len = points.length()
  let ops = []
  if len > 3 {
    let s = 1.0 - o.curve_tightness
    ops.push(Move(points[1].x, points[1].y))
    for i = 1; i + 2 < len; i = i + 1 {
      let cached = points[i]
      let b1x = cached.x + (s * points[i + 1].x - s * points[i - 1].x) / 6.0
      let b1y = cached.y + (s * points[i + 1].y - s * points[i - 1].y) / 6.0
      let b2x = points[i + 1].x + (s * points[i].x - s * points[i + 2].x) / 6.0
      let b2y = points[i + 1].y + (s * points[i].y - s * points[i + 2].y) / 6.0
      ops.push(BCurveTo(b1x, b1y, b2x, b2y, points[i + 1].x, points[i + 1].y))
    }
  } else if len == 3 {
    ops.push(Move(points[1].x, points[1].y))
    ops.push(
      BCurveTo(
        points[1].x,
        points[1].y,
        points[2].x,
        points[2].y,
        points[2].x,
        points[2].y,
      ),
    )
  } else if len == 2 {
    ops.append(
      line_ops(
        points[0].x,
        points[0].y,
        points[1].x,
        points[1].y,
        o,
        true,
        true,
      ),
    )
  }
  ops
}

///|
fn compute_ellipse_points(
  increment : Double,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  offset : Double,
  overlap : Double,
  o : ResolvedOptions,
) -> (Array[Point], Array[Point]) {
  let core_only = o.roughness == 0.0
  let core_points = []
  let all_points = []
  if core_only {
    let increment = increment / 4.0
    all_points.push(
      Point::new(
        cx + rx * @jsmath.cos(-increment),
        cy + ry * @jsmath.sin(-increment),
      ),
    )
    // rough.js loops forever when the increment is zero or negative.
    if increment.is_nan() || increment > 0.0 {
      for angle = 0.0; angle <= @jsmath.PI * 2.0; angle = angle + increment {
        let p = Point::new(
          cx + rx * @jsmath.cos(angle),
          cy + ry * @jsmath.sin(angle),
        )
        core_points.push(p)
        all_points.push(p)
      }
    }
    all_points.push(
      Point::new(cx + rx * @jsmath.cos(0.0), cy + ry * @jsmath.sin(0.0)),
    )
    all_points.push(
      Point::new(
        cx + rx * @jsmath.cos(increment),
        cy + ry * @jsmath.sin(increment),
      ),
    )
  } else {
    let rad_offset = offset_opt(0.5, o) - @jsmath.PI / 2.0
    let x0 = offset_opt(offset, o) +
      cx +
      0.9 * rx * @jsmath.cos(rad_offset - increment)
    let y0 = offset_opt(offset, o) +
      cy +
      0.9 * ry * @jsmath.sin(rad_offset - increment)
    all_points.push(Point::new(x0, y0))
    let end_angle = @jsmath.PI * 2.0 + rad_offset - 0.01
    if increment.is_nan() || increment > 0.0 {
      for angle = rad_offset; angle < end_angle; angle = angle + increment {
        let x = offset_opt(offset, o) + cx + rx * @jsmath.cos(angle)
        let y = offset_opt(offset, o) + cy + ry * @jsmath.sin(angle)
        let p = Point::new(x, y)
        core_points.push(p)
        all_points.push(p)
      }
    }
    let x1 = offset_opt(offset, o) +
      cx +
      rx * @jsmath.cos(rad_offset + @jsmath.PI * 2.0 + overlap * 0.5)
    let y1 = offset_opt(offset, o) +
      cy +
      ry * @jsmath.sin(rad_offset + @jsmath.PI * 2.0 + overlap * 0.5)
    all_points.push(Point::new(x1, y1))
    let x2 = offset_opt(offset, o) +
      cx +
      0.98 * rx * @jsmath.cos(rad_offset + overlap)
    let y2 = offset_opt(offset, o) +
      cy +
      0.98 * ry * @jsmath.sin(rad_offset + overlap)
    all_points.push(Point::new(x2, y2))
    let x3 = offset_opt(offset, o) +
      cx +
      0.9 * rx * @jsmath.cos(rad_offset + overlap * 0.5)
    let y3 = offset_opt(offset, o) +
      cy +
      0.9 * ry * @jsmath.sin(rad_offset + overlap * 0.5)
    all_points.push(Point::new(x3, y3))
  }
  (all_points, core_points)
}

///|
fn arc_ops(
  increment : Double,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  strt : Double,
  stp : Double,
  offset : Double,
  o : ResolvedOptions,
) -> Array[Op] {
  let rad_offset = strt + offset_opt(0.1, o)
  let points = []
  let x0 = offset_opt(offset, o) +
    cx +
    0.9 * rx * @jsmath.cos(rad_offset - increment)
  let y0 = offset_opt(offset, o) +
    cy +
    0.9 * ry * @jsmath.sin(rad_offset - increment)
  points.push(Point::new(x0, y0))
  // rough.js loops forever when the increment is zero or negative.
  if increment.is_nan() || increment > 0.0 {
    for angle = rad_offset; angle <= stp; angle = angle + increment {
      let x = offset_opt(offset, o) + cx + rx * @jsmath.cos(angle)
      let y = offset_opt(offset, o) + cy + ry * @jsmath.sin(angle)
      points.push(Point::new(x, y))
    }
  }
  points.push(
    Point::new(cx + rx * @jsmath.cos(stp), cy + ry * @jsmath.sin(stp)),
  )
  points.push(
    Point::new(cx + rx * @jsmath.cos(stp), cy + ry * @jsmath.sin(stp)),
  )
  curve_ops(points, o)
}

///|
fn bezier_to(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
  current : (Double, Double),
  o : ResolvedOptions,
) -> Array[Op] {
  let ops = []
  let ros = [
    js_or(o.max_randomness_offset, 1.0),
    js_or(o.max_randomness_offset, 1.0) + 0.3,
  ]
  let iterations = if o.disable_multi_stroke { 1 } else { 2 }
  let preserve_vertices = o.preserve_vertices
  for i in 0..<iterations {
    if i == 0 {
      ops.push(Move(current.0, current.1))
    } else {
      let mx = current.0 +
        (if preserve_vertices { 0.0 } else { offset_opt(ros[0], o) })
      let my = current.1 +
        (if preserve_vertices { 0.0 } else { offset_opt(ros[0], o) })
      ops.push(Move(mx, my))
    }
    // The end point's random numbers come before the control points'.
    let (fx, fy) = if preserve_vertices {
      (x, y)
    } else {
      let fx = x + offset_opt(ros[i], o)
      let fy = y + offset_opt(ros[i], o)
      (fx, fy)
    }
    let c1x = x1 + offset_opt(ros[i], o)
    let c1y = y1 + offset_opt(ros[i], o)
    let c2x = x2 + offset_opt(ros[i], o)
    let c2y = y2 + offset_opt(ros[i], o)
    ops.push(BCurveTo(c1x, c1y, c2x, c2y, fx, fy))
  }
  ops
}
