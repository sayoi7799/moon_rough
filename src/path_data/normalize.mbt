// Port of path-data-parser 0.1.0 src/normalize.ts.

///|
/// `normalize(segments)`: turns absolute segments (see `absolutize`) into
/// `M`, `L`, `C` and `Z` only. `H`/`V` become lines; `S`, `Q`, `T` and arcs
/// become cubic Béziers.
pub fn normalize(segments : Array[Segment]) -> Array[Segment] {
  let out = []
  let mut last_type = ' '
  let mut cx = 0.0
  let mut cy = 0.0
  let mut subx = 0.0
  let mut suby = 0.0
  let mut lcx = 0.0
  let mut lcy = 0.0
  for segment in segments {
    let data = segment.data
    match segment.key {
      'M' => {
        out.push({ key: 'M', data: data.copy(), })
        cx = data[0]
        cy = data[1]
        subx = data[0]
        suby = data[1]
      }
      'C' => {
        out.push({ key: 'C', data: data.copy(), })
        cx = data[4]
        cy = data[5]
        lcx = data[2]
        lcy = data[3]
      }
      'L' => {
        out.push({ key: 'L', data: data.copy(), })
        cx = data[0]
        cy = data[1]
      }
      'H' => {
        cx = data[0]
        out.push({ key: 'L', data: [cx, cy], })
      }
      'V' => {
        cy = data[0]
        out.push({ key: 'L', data: [cx, cy], })
      }
      'S' => {
        let (cx1, cy1) = if last_type == 'C' || last_type == 'S' {
          (cx + (cx - lcx), cy + (cy - lcy))
        } else {
          (cx, cy)
        }
        out.push({
          key: 'C',
          data: [cx1, cy1, data[0], data[1], data[2], data[3]],
        })
        lcx = data[0]
        lcy = data[1]
        cx = data[2]
        cy = data[3]
      }
      'T' => {
        let x = data[0]
        let y = data[1]
        let (x1, y1) = if last_type == 'Q' || last_type == 'T' {
          (cx + (cx - lcx), cy + (cy - lcy))
        } else {
          (cx, cy)
        }
        let cx1 = cx + 2.0 * (x1 - cx) / 3.0
        let cy1 = cy + 2.0 * (y1 - cy) / 3.0
        let cx2 = x + 2.0 * (x1 - x) / 3.0
        let cy2 = y + 2.0 * (y1 - y) / 3.0
        out.push({ key: 'C', data: [cx1, cy1, cx2, cy2, x, y], })
        lcx = x1
        lcy = y1
        cx = x
        cy = y
      }
      'Q' => {
        let x1 = data[0]
        let y1 = data[1]
        let x = data[2]
        let y = data[3]
        let cx1 = cx + 2.0 * (x1 - cx) / 3.0
        let cy1 = cy + 2.0 * (y1 - cy) / 3.0
        let cx2 = x + 2.0 * (x1 - x) / 3.0
        let cy2 = y + 2.0 * (y1 - y) / 3.0
        out.push({ key: 'C', data: [cx1, cy1, cx2, cy2, x, y], })
        lcx = x1
        lcy = y1
        cx = x
        cy = y
      }
      'A' => {
        let r1 = data[0].abs()
        let r2 = data[1].abs()
        let angle = data[2]
        let large_arc_flag = data[3]
        let sweep_flag = data[4]
        let x = data[5]
        let y = data[6]
        if r1 == 0.0 || r2 == 0.0 {
          out.push({ key: 'C', data: [cx, cy, x, y, x, y], })
          cx = x
          cy = y
        } else if cx != x || cy != y {
          let curves = arc_to_cubic_curves(
            cx, cy, x, y, r1, r2, angle, large_arc_flag, sweep_flag,
          )
          for curve in curves {
            out.push({ key: 'C', data: curve, })
          }
          cx = x
          cy = y
        }
      }
      'Z' => {
        out.push({ key: 'Z', data: [], })
        cx = subx
        cy = suby
      }
      _ => ()
    }
    last_type = segment.key
  }
  out
}

///|
fn deg_to_rad(degrees : Double) -> Double {
  @jsmath.PI * degrees / 180.0
}

///|
fn rotate(x : Double, y : Double, angle_rad : Double) -> (Double, Double) {
  let cos = @jsmath.cos(angle_rad)
  let sin = @jsmath.sin(angle_rad)
  (x * cos - y * sin, x * sin + y * cos)
}

///|
/// JavaScript truthiness of a number used as an arc flag.
fn truthy(flag : Double) -> Bool {
  flag != 0.0 && !flag.is_nan()
}

///|
/// `parseFloat(x.toFixed(9))`.
fn round9(x : Double) -> Double {
  @jsmath.parse_float(@jsmath.to_fixed(x, 9))
}

///|
/// `arcToCubicCurves` without the `recursive` argument: the endpoint
/// parameterization of an SVG arc, split into pieces of at most 120 degrees.
fn arc_to_cubic_curves(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  r1 : Double,
  r2 : Double,
  angle : Double,
  large_arc_flag : Double,
  sweep_flag : Double,
) -> Array[Array[Double]] {
  let angle_rad = deg_to_rad(angle)
  let (x1, y1) = rotate(x1, y1, -angle_rad)
  let (x2, y2) = rotate(x2, y2, -angle_rad)
  let x = (x1 - x2) / 2.0
  let y = (y1 - y2) / 2.0
  let mut h = x * x / (r1 * r1) + y * y / (r2 * r2)
  let mut r1 = r1
  let mut r2 = r2
  if h > 1.0 {
    h = h.sqrt()
    r1 = h * r1
    r2 = h * r2
  }
  let sign = if large_arc_flag == sweep_flag { -1.0 } else { 1.0 }
  let r1_pow = r1 * r1
  let r2_pow = r2 * r2
  let left = r1_pow * r2_pow - r1_pow * y * y - r2_pow * x * x
  let right = r1_pow * y * y + r2_pow * x * x
  let k = sign * (left / right).abs().sqrt()
  let cx = k * r1 * y / r2 + (x1 + x2) / 2.0
  let cy = k * -r2 * x / r1 + (y1 + y2) / 2.0
  let mut f1 = @jsmath.asin(round9((y1 - cy) / r2))
  let mut f2 = @jsmath.asin(round9((y2 - cy) / r2))
  if x1 < cx {
    f1 = @jsmath.PI - f1
  }
  if x2 < cx {
    f2 = @jsmath.PI - f2
  }
  if f1 < 0.0 {
    f1 = @jsmath.PI * 2.0 + f1
  }
  if f2 < 0.0 {
    f2 = @jsmath.PI * 2.0 + f2
  }
  if truthy(sweep_flag) && f1 > f2 {
    f1 = f1 - @jsmath.PI * 2.0
  }
  if !truthy(sweep_flag) && f2 > f1 {
    f2 = f2 - @jsmath.PI * 2.0
  }
  let params = arc_pieces(x1, y1, x2, y2, r1, r2, sweep_flag, f1, f2, cx, cy)
  let curves = []
  for i = 0; i < params.length(); i = i + 3 {
    let (ax, ay) = rotate(params[i].0, params[i].1, angle_rad)
    let (bx, by) = rotate(params[i + 1].0, params[i + 1].1, angle_rad)
    let (ex, ey) = rotate(params[i + 2].0, params[i + 2].1, angle_rad)
    curves.push([ax, ay, bx, by, ex, ey])
  }
  curves
}

///|
/// The part of `arcToCubicCurves` shared by the outer and the `recursive`
/// calls: control points `[m2, m3, m4, ...]` of the pieces from angle `f1`
/// to `f2`, in the arc's unrotated frame.
fn arc_pieces(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  r1 : Double,
  r2 : Double,
  sweep_flag : Double,
  f1 : Double,
  f2 : Double,
  cx : Double,
  cy : Double,
) -> Array[(Double, Double)] {
  let mut f2 = f2
  let mut x2 = x2
  let mut y2 = y2
  let mut params = []
  let mut df = f2 - f1
  if df.abs() > @jsmath.PI * 120.0 / 180.0 {
    let f2old = f2
    let x2old = x2
    let y2old = y2
    if truthy(sweep_flag) && f2 > f1 {
      f2 = f1 + @jsmath.PI * 120.0 / 180.0 * 1.0
    } else {
      f2 = f1 + @jsmath.PI * 120.0 / 180.0 * -1.0
    }
    x2 = cx + r1 * @jsmath.cos(f2)
    y2 = cy + r2 * @jsmath.sin(f2)
    params = arc_pieces(
      x2, y2, x2old, y2old, r1, r2, sweep_flag, f2, f2old, cx, cy,
    )
  }
  df = f2 - f1
  let c1 = @jsmath.cos(f1)
  let s1 = @jsmath.sin(f1)
  let c2 = @jsmath.cos(f2)
  let s2 = @jsmath.sin(f2)
  let t = @jsmath.tan(df / 4.0)
  let hx = 4.0 / 3.0 * r1 * t
  let hy = 4.0 / 3.0 * r2 * t
  let m2x = x1 + hx * s1
  let m2y = y1 - hy * c1
  let m3 = (x2 + hx * s2, y2 - hy * c2)
  let m4 = (x2, y2)
  let m2 = (2.0 * x1 - m2x, 2.0 * y1 - m2y)
  [m2, m3, m4, ..params]
}
