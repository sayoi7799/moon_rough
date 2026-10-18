// Port of rough.js 4.6.6 src/fillers/: filler.ts, scan-line-hachure.ts and
// the pattern fillers.

///|
/// `getFiller(o, helper).fillPolygons(polygonList, o)`.
fn fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  match o.fill_style {
    _ => hachure_fill_polygons(polygon_list, o)
  }
}

///|
/// `polygonHachureLines(polygonList, o)` of scan-line-hachure.ts.
fn polygon_hachure_lines(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> Array[@hachure.Line] {
  let angle = o.hachure_angle + 90.0
  let mut gap = o.hachure_gap
  if gap < 0.0 {
    gap = o.stroke_width * 4.0
  }
  gap = @jsmath.round(@jsmath.max(gap, 0.1))
  let mut skip_offset = 1.0
  if o.roughness >= 1.0 {
    // `(o.randomizer?.next() || Math.random()) > 0.7`: no randomizer is
    // created here, and a 0 from it falls back to Math.random().
    let r = match o.randomizer {
      Some(randomizer) => randomizer.next()
      None => 0.0
    }
    let r = if truthy(r) { r } else { o.source.fallback() }
    if r > 0.7 {
      skip_offset = gap
    }
  }
  @hachure.hachure_lines(
    polygon_list,
    gap,
    angle,
    hachure_step_offset=js_or(skip_offset, 1.0),
  )
}

///|
/// `HachureFiller.renderLines`.
fn render_lines(lines : Array[@hachure.Line], o : ResolvedOptions) -> Array[Op] {
  let ops = []
  for line in lines {
    ops.append(double_line_fill_ops(line.0.x, line.0.y, line.1.x, line.1.y, o))
  }
  ops
}

///|
/// `HachureFiller._fillPolygons`.
fn hachure_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let lines = polygon_hachure_lines(polygon_list, o)
  { kind: FillSketch, ops: render_lines(lines, o), }
}
