// Port of points-on-curve 0.2.0 (github.com/pshihn/bezier-points):
// src/index.ts and src/curve-to-bezier.ts.

///|
using @geometry {type Point}

///|
fn distance_sq(p1 : Point, p2 : Point) -> Double {
  let dx = p1.x - p2.x
  let dy = p1.y - p2.y
  dx * dx + dy * dy
}

///|
fn distance(p1 : Point, p2 : Point) -> Double {
  distance_sq(p1, p2).sqrt()
}

///|
fn lerp(a : Point, b : Point, t : Double) -> Point {
  { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, }
}

///|
/// Squared distance from `p` to the segment `vw`.
fn distance_to_segment_sq(p : Point, v : Point, w : Point) -> Double {
  let l2 = distance_sq(v, w)
  if l2 == 0.0 {
    return distance_sq(p, v)
  }
  let mut t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
  t = @jsmath.max(0.0, @jsmath.min(1.0, t))
  distance_sq(p, lerp(v, w, t))
}

///|
fn flatness(points : Array[Point], offset : Int) -> Double {
  let p1 = points[offset + 0]
  let p2 = points[offset + 1]
  let p3 = points[offset + 2]
  let p4 = points[offset + 3]
  let mut ux = 3.0 * p2.x - 2.0 * p1.x - p4.x
  ux *= ux
  let mut uy = 3.0 * p2.y - 2.0 * p1.y - p4.y
  uy *= uy
  let mut vx = 3.0 * p3.x - 2.0 * p4.x - p1.x
  vx *= vx
  let mut vy = 3.0 * p3.y - 2.0 * p4.y - p1.y
  vy *= vy
  if ux < vx {
    ux = vx
  }
  if uy < vy {
    uy = vy
  }
  ux + uy
}

///|
fn points_on_bezier_curve_with_splitting(
  points : Array[Point],
  offset : Int,
  tolerance : Double,
  out_points : Array[Point],
) -> Unit {
  if flatness(points, offset) < tolerance {
    let p0 = points[offset + 0]
    if out_points.length() > 0 {
      let d = distance(out_points[out_points.length() - 1], p0)
      if d > 1.0 {
        out_points.push(p0)
      }
    } else {
      out_points.push(p0)
    }
    out_points.push(points[offset + 3])
  } else {
    // subdivide
    let t = 0.5
    let p1 = points[offset + 0]
    let p2 = points[offset + 1]
    let p3 = points[offset + 2]
    let p4 = points[offset + 3]
    let q1 = lerp(p1, p2, t)
    let q2 = lerp(p2, p3, t)
    let q3 = lerp(p3, p4, t)
    let r1 = lerp(q1, q2, t)
    let r2 = lerp(q2, q3, t)
    let red = lerp(r1, r2, t)
    points_on_bezier_curve_with_splitting(
      [p1, q1, r1, red],
      0,
      tolerance,
      out_points,
    )
    points_on_bezier_curve_with_splitting(
      [red, r2, q3, p4],
      0,
      tolerance,
      out_points,
    )
  }
}

///|
/// `simplify(points, distance)`: Ramer-Douglas-Peucker simplification.
/// The result shares the input's points.
pub fn simplify(points : Array[Point], distance : Double) -> Array[Point] {
  if points.length() == 0 {
    return []
  }
  let out = []
  simplify_points(points, 0, points.length(), distance, out)
  out
}

///|
fn simplify_points(
  points : Array[Point],
  start : Int,
  end : Int,
  epsilon : Double,
  out_points : Array[Point],
) -> Unit {
  // find the most distance point from the endpoints
  let s = points[start]
  let e = points[end - 1]
  let mut max_dist_sq = 0.0
  let mut max_ndx = 1
  for i in (start + 1)..<(end - 1) {
    let dist_sq = distance_to_segment_sq(points[i], s, e)
    if dist_sq > max_dist_sq {
      max_dist_sq = dist_sq
      max_ndx = i
    }
  }
  // if that point is too far, split
  if max_dist_sq.sqrt() > epsilon {
    simplify_points(points, start, max_ndx + 1, epsilon, out_points)
    simplify_points(points, max_ndx, end, epsilon, out_points)
  } else {
    if out_points.length() == 0 {
      out_points.push(s)
    }
    out_points.push(e)
  }
}

///|
/// `pointsOnBezierCurves(points, tolerance, distance)`: flattens a chain of
/// cubic Béziers (`[p0, c1, c2, p1, c1, c2, p2, ...]`) into a polyline whose
/// flatness is below `tolerance`, then simplifies it with `distance` when that
/// is given and positive.
pub fn points_on_bezier_curves(
  points : Array[Point],
  tolerance? : Double = 0.15,
  distance? : Double,
) -> Array[Point] {
  let new_points = []
  // `(points.length - 1) / 3` is fractional for incomplete chains; the loop
  // `i < numSegments` then runs ceil(...) times.
  let num_segments = (points.length() - 1).to_double() / 3.0
  for i = 0; i.to_double() < num_segments; i = i + 1 {
    points_on_bezier_curve_with_splitting(points, i * 3, tolerance, new_points)
  }
  match distance {
    Some(d) if d > 0.0 =>
      if new_points.length() == 0 {
        // simplifyPoints would read points[-1] (undefined) here.
        new_points
      } else {
        let out = []
        simplify_points(new_points, 0, new_points.length(), d, out)
        out
      }
    _ => new_points
  }
}

///|
/// `curveToBezier` needs at least three points.
pub(all) suberror CurveTooShort derive(Debug)

///|
/// `curveToBezier(points, curveTightness)`: the cubic Bézier chain of the
/// Catmull-Rom-like curve rough.js draws through `points_in`.
pub fn curve_to_bezier(
  points_in : Array[Point],
  curve_tightness? : Double = 0.0,
) -> Array[Point] raise CurveTooShort {
  let len = points_in.length()
  if len < 3 {
    raise CurveTooShort
  }
  let out = []
  if len == 3 {
    out.push(points_in[0].copy())
    out.push(points_in[1].copy())
    out.push(points_in[2].copy())
    out.push(points_in[2].copy())
  } else {
    let points = []
    points.push(points_in[0])
    points.push(points_in[0])
    for i in 1..<points_in.length() {
      points.push(points_in[i])
      if i == points_in.length() - 1 {
        points.push(points_in[i])
      }
    }
    let s = 1.0 - curve_tightness
    out.push(points[0].copy())
    for i = 1; i + 2 < points.length(); i = i + 1 {
      let cached = points[i]
      let b1 = Point::new(
        cached.x + (s * points[i + 1].x - s * points[i - 1].x) / 6.0,
        cached.y + (s * points[i + 1].y - s * points[i - 1].y) / 6.0,
      )
      let b2 = Point::new(
        points[i + 1].x + (s * points[i].x - s * points[i + 2].x) / 6.0,
        points[i + 1].y + (s * points[i].y - s * points[i + 2].y) / 6.0,
      )
      let b3 = Point::new(points[i + 1].x, points[i + 1].y)
      out.push(b1)
      out.push(b2)
      out.push(b3)
    }
  }
  out
}
