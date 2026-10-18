// Port of rough.js 4.6.6 src/fillers/: filler.ts, scan-line-hachure.ts and
// the pattern fillers.

///|
/// `getFiller(o, helper).fillPolygons(polygonList, o)`.
fn fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  match o.fill_style {
    Zigzag => zigzag_fill_polygons(polygon_list, o)
    CrossHatch => hatch_fill_polygons(polygon_list, o)
    Dots => dot_fill_polygons(polygon_list, o)
    Dashed => dashed_fill_polygons(polygon_list, o)
    ZigzagLine => zigzag_line_fill_polygons(polygon_list, o)
    // `solid` never reaches the pattern fillers in the generator; rough.js'
    // getFiller maps it (like any unknown name) to the hachure filler.
    Hachure | Solid => hachure_fill_polygons(polygon_list, o)
  }
}

///|
/// The gap of the zigzag and dots fillers:
/// `max(hachureGap < 0 ? strokeWidth * 4 : hachureGap, 0.1)`.
fn filler_gap(o : ResolvedOptions) -> Double {
  let mut gap = o.hachure_gap
  if gap < 0.0 {
    gap = o.stroke_width * 4.0
  }
  @jsmath.max(gap, 0.1)
}

///|
/// `ZigZagFiller.fillPolygons` (zigzag-filler.ts).
fn zigzag_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let gap = filler_gap(o)
  let o2 = { ..o, hachure_gap: gap, }
  let lines = polygon_hachure_lines(polygon_list, o2)
  let zigzag_angle = @jsmath.PI / 180.0 * o.hachure_angle
  let zigzag_lines = []
  let dgx = gap * 0.5 * @jsmath.cos(zigzag_angle)
  let dgy = gap * 0.5 * @jsmath.sin(zigzag_angle)
  for line in lines {
    let (p1, p2) = line
    if truthy(@geometry.line_length(p1, p2)) {
      zigzag_lines.push((Point::new(p1.x - dgx, p1.y + dgy), p2.copy()))
      zigzag_lines.push((Point::new(p1.x + dgx, p1.y - dgy), p2.copy()))
    }
  }
  { kind: FillSketch, ops: render_lines(zigzag_lines, o), }
}

///|
/// `HatchFiller.fillPolygons` (hatch-filler.ts): hachures at the angle and
/// at the angle + 90. The second pass sees the polygons as the first pass
/// left them (rotated there and back by hachure-fill).
fn hatch_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let set = hachure_fill_polygons(polygon_list, o)
  let o2 = { ..o, hachure_angle: o.hachure_angle + 90.0, }
  let set2 = hachure_fill_polygons(polygon_list, o2)
  { kind: set.kind, ops: [..set.ops, ..set2.ops], }
}

///|
/// `DotFiller.fillPolygons` (dot-filler.ts). The dot positions come from
/// `Math.random()`, i.e. from the options' random source.
fn dot_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let o = { ..o, hachure_angle: 0.0, }
  let lines = polygon_hachure_lines(polygon_list, o)
  let ops = []
  let gap = filler_gap(o)
  let mut fweight = o.fill_weight
  if fweight < 0.0 {
    fweight = o.stroke_width / 2.0
  }
  let ro = gap / 4.0
  for line in lines {
    let length = @geometry.line_length(line.0, line.1)
    let dl = length / gap
    let count = dl.ceil() - 1.0
    let offset = length - count * gap
    let x = (line.0.x + line.1.x) / 2.0 - gap / 4.0
    let min_y = @jsmath.min(line.0.y, line.1.y)
    for i = 0.0; i < count; i = i + 1.0 {
      let y = min_y + offset + i * gap
      let cx = x - ro + o.source.fallback() * 2.0 * ro
      let cy = y - ro + o.source.fallback() * 2.0 * ro
      let el = ellipse(cx, cy, fweight, fweight, o)
      ops.append(el.ops)
    }
  }
  { kind: FillSketch, ops, }
}

///|
/// `DashedFiller.fillPolygons` (dashed-filler.ts).
fn dashed_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let lines = polygon_hachure_lines(polygon_list, o)
  let default_gap = if o.hachure_gap < 0.0 {
    o.stroke_width * 4.0
  } else {
    o.hachure_gap
  }
  let offset = if o.dash_offset < 0.0 { default_gap } else { o.dash_offset }
  let gap = if o.dash_gap < 0.0 { default_gap } else { o.dash_gap }
  let ops = []
  for line in lines {
    let length = @geometry.line_length(line.0, line.1)
    let count = (length / (offset + gap)).floor()
    let start_offset = (length + gap - count * (offset + gap)) / 2.0
    let (p1, p2) = if line.0.x > line.1.x { (line.1, line.0) } else { line }
    let alpha = @jsmath.atan((p2.y - p1.y) / (p2.x - p1.x))
    // rough.js never finishes when offset + gap is 0 (count is Infinity).
    if count.is_inf() {
      continue
    }
    for i = 0.0; i < count; i = i + 1.0 {
      let lstart = i * (offset + gap)
      let lend = lstart + offset
      let cos = @jsmath.cos(alpha)
      let sin = @jsmath.sin(alpha)
      let start_x = p1.x + lstart * cos + start_offset * cos
      let start_y = p1.y + lstart * sin + start_offset * sin
      let end_x = p1.x + lend * cos + start_offset * cos
      let end_y = p1.y + lend * sin + start_offset * sin
      ops.append(double_line_fill_ops(start_x, start_y, end_x, end_y, o))
    }
  }
  { kind: FillSketch, ops, }
}

///|
/// `ZigZagLineFiller.fillPolygons` (zigzag-line-filler.ts).
fn zigzag_line_fill_polygons(
  polygon_list : Array[Array[Point]],
  o : ResolvedOptions,
) -> OpSet {
  let gap = if o.hachure_gap < 0.0 {
    o.stroke_width * 4.0
  } else {
    o.hachure_gap
  }
  let zo = if o.zigzag_offset < 0.0 { gap } else { o.zigzag_offset }
  let o = { ..o, hachure_gap: gap + zo, }
  let lines = polygon_hachure_lines(polygon_list, o)
  let ops = []
  for line in lines {
    let length = @geometry.line_length(line.0, line.1)
    let count = @jsmath.round(length / (2.0 * zo))
    let (p1, p2) = if line.0.x > line.1.x { (line.1, line.0) } else { line }
    let alpha = @jsmath.atan((p2.y - p1.y) / (p2.x - p1.x))
    // rough.js never finishes when zigzagOffset is 0 (count is Infinity).
    if count.is_inf() {
      continue
    }
    for i = 0.0; i < count; i = i + 1.0 {
      let lstart = i * 2.0 * zo
      let lend = (i + 1.0) * 2.0 * zo
      let dz = (2.0 * (zo * zo)).sqrt()
      let start_x = p1.x + lstart * @jsmath.cos(alpha)
      let start_y = p1.y + lstart * @jsmath.sin(alpha)
      let end_x = p1.x + lend * @jsmath.cos(alpha)
      let end_y = p1.y + lend * @jsmath.sin(alpha)
      let middle_x = start_x + dz * @jsmath.cos(alpha + @jsmath.PI / 4.0)
      let middle_y = start_y + dz * @jsmath.sin(alpha + @jsmath.PI / 4.0)
      ops.append(double_line_fill_ops(start_x, start_y, middle_x, middle_y, o))
      ops.append(double_line_fill_ops(middle_x, middle_y, end_x, end_y, o))
    }
  }
  { kind: FillSketch, ops, }
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
