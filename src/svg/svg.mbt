// SVG output, following rough.js 4.6.6 src/svg.ts (RoughSVG.draw), which
// builds DOM elements; here they are serialized to strings.

///|
/// A `<g>` element with one `<path>` per op set of `drawable`, with the
/// attributes `RoughSVG.draw` sets, in the same order. Coordinates are
/// rounded to `fixed_decimal_place_digits` when that option is set.
pub fn drawable_to_svg(drawable : @core.Drawable) -> String {
  let o = drawable.options
  let precision = o.fixed_decimal_place_digits
  let g = StringBuilder()
  g.write_string("<g>")
  for drawing in drawable.sets {
    let attrs : Array[(String, String)] = []
    match drawing.kind {
      Path => {
        attrs.push(("d", @core.ops_to_path(drawing, fixed_decimals?=precision)))
        attrs.push(("stroke", o.stroke))
        attrs.push(("stroke-width", @jsmath.number_to_string(o.stroke_width)))
        attrs.push(("fill", "none"))
        if o.stroke_line_dash is Some(dash) {
          attrs.push(("stroke-dasharray", dash_array(dash)))
        }
        if o.stroke_line_dash_offset is Some(offset) && truthy(offset) {
          attrs.push(("stroke-dashoffset", @jsmath.number_to_string(offset)))
        }
      }
      FillPath => {
        attrs.push(("d", @core.ops_to_path(drawing, fixed_decimals?=precision)))
        attrs.push(("stroke", "none"))
        attrs.push(("stroke-width", "0"))
        attrs.push(("fill", o.fill.unwrap_or("")))
        if drawable.shape is (Curve | Polygon) {
          attrs.push(("fill-rule", "evenodd"))
        }
      }
      FillSketch => {
        let mut fweight = o.fill_weight
        if fweight < 0.0 {
          fweight = o.stroke_width / 2.0
        }
        attrs.push(("d", @core.ops_to_path(drawing, fixed_decimals?=precision)))
        attrs.push(("stroke", o.fill.unwrap_or("")))
        attrs.push(("stroke-width", @jsmath.number_to_string(fweight)))
        attrs.push(("fill", "none"))
        if o.fill_line_dash is Some(dash) {
          attrs.push(("stroke-dasharray", dash_array(dash)))
        }
        if o.fill_line_dash_offset is Some(offset) && truthy(offset) {
          attrs.push(("stroke-dashoffset", @jsmath.number_to_string(offset)))
        }
      }
    }
    g.write_string("<path")
    for attr in attrs {
      g.write_string(" \{attr.0}=\"\{escape_attribute(attr.1)}\"")
    }
    g.write_string("/>")
  }
  g.write_string("</g>")
  g.to_string()
}

///|
/// A standalone SVG document of the given size containing `content`
/// (for example the result of `drawable_to_svg`).
pub fn svg_document(
  width : Double,
  height : Double,
  content : String,
  background? : String,
) -> String {
  let w = @jsmath.number_to_string(width)
  let h = @jsmath.number_to_string(height)
  let buf = StringBuilder()
  buf.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{w}\" height=\"\{h}\" viewBox=\"0 0 \{w} \{h}\">",
  )
  if background is Some(fill) {
    buf.write_string(
      "<rect width=\"100%\" height=\"100%\" fill=\"\{escape_attribute(fill)}\"/>",
    )
  }
  buf.write_string(content)
  buf.write_string("</svg>")
  buf.to_string()
}

///|
/// `strokeLineDash.join(' ').trim()`.
fn dash_array(dash : Array[Double]) -> String {
  dash.map(@jsmath.number_to_string).join(" ").trim().to_owned()
}

///|
/// JavaScript truthiness of a number.
fn truthy(x : Double) -> Bool {
  x != 0.0 && !x.is_nan()
}

///|
/// Escapes `&`, `<`, `>` and `"` for use in a double-quoted attribute.
pub fn escape_attribute(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      c => buf.write_char(c)
    }
  }
  buf.to_string()
}
