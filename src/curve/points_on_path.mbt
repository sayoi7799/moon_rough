// Port of points-on-path 0.2.1 src/index.ts.

///|
/// `pointsOnPath(path, tolerance, distance)`: the polylines (one per
/// subpath) approximating SVG path data. Curves are flattened with
/// `tolerance` (default 0.15); when `distance` is given and non-zero each
/// polyline is simplified with it.
pub fn points_on_path(
  path : StringView,
  tolerance? : Double,
  distance? : Double,
) -> Array[Array[Point]] raise @path_data.PathError {
  let segments = @path_data.parse_path(path)
  let normalized = @path_data.normalize(@path_data.absolutize(segments))
  let sets = []
  let mut current_points = []
  let mut start = Point::new(0.0, 0.0)
  let mut pending_curve = []
  fn append_pending_curve() {
    if pending_curve.length() >= 4 {
      let points = match tolerance {
        Some(tolerance) => points_on_bezier_curves(pending_curve, tolerance~)
        None => points_on_bezier_curves(pending_curve)
      }
      current_points.append(points)
    }
    pending_curve = []
  }

  fn append_pending_points() {
    append_pending_curve()
    if current_points.length() > 0 {
      sets.push(current_points)
      current_points = []
    }
  }

  for segment in normalized {
    let data = segment.data
    match segment.key {
      'M' => {
        append_pending_points()
        start = Point::new(data[0], data[1])
        current_points.push(start)
      }
      'L' => {
        append_pending_curve()
        current_points.push(Point::new(data[0], data[1]))
      }
      'C' => {
        if pending_curve.length() == 0 {
          let last_point = if current_points.length() > 0 {
            current_points[current_points.length() - 1]
          } else {
            start
          }
          pending_curve.push(last_point.copy())
        }
        pending_curve.push(Point::new(data[0], data[1]))
        pending_curve.push(Point::new(data[2], data[3]))
        pending_curve.push(Point::new(data[4], data[5]))
      }
      'Z' => {
        append_pending_curve()
        current_points.push(start.copy())
      }
      _ => ()
    }
  }
  append_pending_points()
  match distance {
    None => sets
    Some(d) if d == 0.0 || d.is_nan() => sets
    Some(d) => {
      let out = []
      for set in sets {
        let simplified_set = simplify(set, d)
        if simplified_set.length() > 0 {
          out.push(simplified_set)
        }
      }
      out
    }
  }
}
