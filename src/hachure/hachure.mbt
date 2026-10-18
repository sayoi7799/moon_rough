// Port of hachure-fill 0.5.2 (bin/hachure.js): scan-line hachure fill.

///|
using @geometry {type Point}

///|
/// A hachure line from the first point to the second.
pub type Line = (Point, Point)

///|
priv struct Edge {
  ymin : Double
  ymax : Double
  mut x : Double
  islope : Double
}

///|
/// Rotates `points` in place by `degrees` around `(cx, cy)`. A point that
/// occurs twice in `points` is rotated twice, as in hachure-fill.
fn rotate_points(
  points : Array[Point],
  cx : Double,
  cy : Double,
  degrees : Double,
) -> Unit {
  if points.length() > 0 {
    let angle = @jsmath.PI / 180.0 * degrees
    let cos = @jsmath.cos(angle)
    let sin = @jsmath.sin(angle)
    for p in points {
      let x = p.x
      let y = p.y
      p.x = (x - cx) * cos - (y - cy) * sin + cx
      p.y = (x - cx) * sin + (y - cy) * cos + cy
    }
  }
}

///|
fn rotate_lines(
  lines : Array[Line],
  cx : Double,
  cy : Double,
  degrees : Double,
) -> Unit {
  let points = []
  for line in lines {
    points.push(line.0)
    points.push(line.1)
  }
  rotate_points(points, cx, cy, degrees)
}

///|
/// `hachureLines(polygons, hachureGap, hachureAngle, hachureStepOffset)`:
/// parallel lines `hachure_gap` apart, at `hachure_angle` degrees, that fill
/// the polygons with the even-odd rule.
///
/// Like hachure-fill, this rotates the polygons' points in place and rotates
/// them back afterwards, so their coordinates can change in the last bits;
/// rough.js depends on that (e.g. the second pass of the cross-hatch filler
/// sees the perturbed points). Empty polygons are skipped (hachure-fill
/// throws a TypeError on them).
pub fn hachure_lines(
  polygons : Array[Array[Point]],
  hachure_gap : Double,
  hachure_angle : Double,
  hachure_step_offset? : Double = 1.0,
) -> Array[Line] {
  let angle = hachure_angle
  let gap = @jsmath.max(hachure_gap, 0.1)
  let rotate = angle != 0.0 && !angle.is_nan()
  if rotate {
    for polygon in polygons {
      rotate_points(polygon, 0.0, 0.0, angle)
    }
  }
  let lines = straight_hachure_lines(polygons, gap, hachure_step_offset)
  if rotate {
    for polygon in polygons {
      rotate_points(polygon, 0.0, 0.0, -angle)
    }
    rotate_lines(lines, 0.0, 0.0, -angle)
  }
  lines
}

///|
fn are_same_points(p1 : Point, p2 : Point) -> Bool {
  p1.x == p2.x && p1.y == p2.y
}

///|
fn straight_hachure_lines(
  polygons : Array[Array[Point]],
  gap : Double,
  hachure_step_offset : Double,
) -> Array[Line] {
  let vertex_array = []
  for polygon in polygons {
    if polygon.length() == 0 {
      continue
    }
    let vertices = polygon.copy()
    if !are_same_points(vertices[0], vertices[vertices.length() - 1]) {
      vertices.push(Point::new(vertices[0].x, vertices[0].y))
    }
    if vertices.length() > 2 {
      vertex_array.push(vertices)
    }
  }
  let lines = []
  let gap = @jsmath.max(gap, 0.1)
  // Create sorted edges table
  let edges : Array[Edge] = []
  for vertices in vertex_array {
    for i in 0..<(vertices.length() - 1) {
      let p1 = vertices[i]
      let p2 = vertices[i + 1]
      if p1.y != p2.y {
        let ymin = @jsmath.min(p1.y, p2.y)
        edges.push({
          ymin,
          ymax: @jsmath.max(p1.y, p2.y),
          x: if ymin == p1.y {
            p1.x
          } else {
            p2.x
          },
          islope: (p2.x - p1.x) / (p2.y - p1.y),
        })
      }
    }
  }
  stable_sort(edges, fn(e1, e2) {
    if e1.ymin < e2.ymin {
      return -1.0
    }
    if e1.ymin > e2.ymin {
      return 1.0
    }
    if e1.x < e2.x {
      return -1.0
    }
    if e1.x > e2.x {
      return 1.0
    }
    if e1.ymax == e2.ymax {
      return 0.0
    }
    (e1.ymax - e2.ymax) / (e1.ymax - e2.ymax).abs()
  })
  if edges.length() == 0 {
    return lines
  }
  // Start scanning
  // edges[next_edge:] are the edges not yet moved to active_edges
  // (`edges.splice(0, ix + 1)` in hachure-fill).
  let mut next_edge = 0
  let mut active_edges : Array[Edge] = []
  let mut y = edges[0].ymin
  let mut iteration = 0
  while active_edges.length() > 0 || next_edge < edges.length() {
    if next_edge < edges.length() {
      let mut ix = next_edge - 1
      for i in next_edge..<edges.length() {
        if edges[i].ymin > y {
          break
        }
        ix = i
      }
      for i in next_edge..<(ix + 1) {
        active_edges.push(edges[i])
      }
      next_edge = ix + 1
    }
    active_edges = active_edges.filter(fn(ae) { !(ae.ymax <= y) })
    stable_sort(active_edges, fn(ae1, ae2) {
      if ae1.x == ae2.x {
        return 0.0
      }
      (ae1.x - ae2.x) / (ae1.x - ae2.x).abs()
    })
    // fill between the edges
    if hachure_step_offset != 1.0 || iteration.to_double() % gap == 0.0 {
      if active_edges.length() > 1 {
        for i = 0; i < active_edges.length(); i = i + 2 {
          let nexti = i + 1
          if nexti >= active_edges.length() {
            break
          }
          let ce = active_edges[i]
          let ne = active_edges[nexti]
          lines.push(
            (
              Point::new(@jsmath.round(ce.x), y),
              Point::new(@jsmath.round(ne.x), y),
            ),
          )
        }
      }
    }
    y += hachure_step_offset
    for ae in active_edges {
      ae.x = ae.x + hachure_step_offset * ae.islope
    }
    iteration += 1
  }
  lines
}

///|
/// Stable merge sort; `compare(a, b) > 0` puts `b` first. The result is the
/// one V8's (stable) `Array.prototype.sort` gives for consistent comparators.
fn[T] stable_sort(items : Array[T], compare : (T, T) -> Double) -> Unit {
  let n = items.length()
  if n < 2 {
    return
  }
  let buffer = items.copy()
  let mut width = 1
  while width < n {
    let mut lo = 0
    while lo < n {
      let mid = if lo + width < n { lo + width } else { n }
      let hi = if lo + 2 * width < n { lo + 2 * width } else { n }
      let mut i = lo
      let mut j = mid
      let mut k = lo
      while i < mid && j < hi {
        if compare(items[i], items[j]) > 0.0 {
          buffer[k] = items[j]
          j += 1
        } else {
          buffer[k] = items[i]
          i += 1
        }
        k += 1
      }
      while i < mid {
        buffer[k] = items[i]
        i += 1
        k += 1
      }
      while j < hi {
        buffer[k] = items[j]
        j += 1
        k += 1
      }
      lo = hi
    }
    for t in 0..<n {
      items[t] = buffer[t]
    }
    width *= 2
  }
}
