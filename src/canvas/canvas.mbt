// Port of rough.js 4.6.6 src/canvas.ts (RoughCanvas).
//
// The drawing code is written against the Canvas2D trait, the part of
// CanvasRenderingContext2D that rough.js uses, so it compiles for every
// target. On js, JsContext binds the trait to a real canvas context (see
// canvas_js.mbt); Recorder implements it by writing the calls down.

///|
/// The part of the HTML canvas 2D context that rough.js draws with.
/// `set_*` are the property assignments (`ctx.strokeStyle = ...`).
pub(open) trait Canvas2D {
  fn save(Self) -> Unit
  fn restore(Self) -> Unit
  fn begin_path(Self) -> Unit
  fn move_to(Self, Double, Double) -> Unit
  fn line_to(Self, Double, Double) -> Unit
  fn bezier_curve_to(Self, Double, Double, Double, Double, Double, Double) -> Unit
  fn stroke(Self) -> Unit
  /// `ctx.fill(rule)` with `"nonzero"` or `"evenodd"`.
  fn fill(Self, String) -> Unit
  fn set_stroke_style(Self, String) -> Unit
  fn set_fill_style(Self, String) -> Unit
  fn set_line_width(Self, Double) -> Unit
  fn set_line_dash(Self, Array[Double]) -> Unit
  fn set_line_dash_offset(Self, Double) -> Unit
}

///|
/// JavaScript truthiness of a number.
fn truthy(x : Double) -> Bool {
  x != 0.0 && !x.is_nan()
}

///|
/// `RoughCanvas.draw(drawable)`: paints the op sets of `drawable` on `ctx`,
/// with the same calls, in the same order and with the same arguments as
/// rough.js.
pub fn[C : Canvas2D] draw(ctx : C, drawable : @core.Drawable) -> Unit {
  let o = drawable.options
  let precision = o.fixed_decimal_place_digits
  for drawing in drawable.sets {
    match drawing.kind {
      Path => {
        ctx.save()
        ctx.set_stroke_style(
          if o.stroke == "none" {
            "transparent"
          } else {
            o.stroke
          },
        )
        ctx.set_line_width(o.stroke_width)
        if o.stroke_line_dash is Some(dash) {
          ctx.set_line_dash(dash)
        }
        if o.stroke_line_dash_offset is Some(offset) && truthy(offset) {
          ctx.set_line_dash_offset(offset)
        }
        draw_to_context(ctx, drawing, precision, "nonzero")
        ctx.restore()
      }
      FillPath => {
        ctx.save()
        ctx.set_fill_style(o.fill.unwrap_or(""))
        let rule = match drawable.shape {
          Curve | Polygon | Path => "evenodd"
          _ => "nonzero"
        }
        draw_to_context(ctx, drawing, precision, rule)
        ctx.restore()
      }
      FillSketch => fill_sketch(ctx, drawing, o)
    }
  }
}

///|
fn[C : Canvas2D] fill_sketch(
  ctx : C,
  drawing : @core.OpSet,
  o : @core.ResolvedOptions,
) -> Unit {
  let mut fweight = o.fill_weight
  if fweight < 0.0 {
    fweight = o.stroke_width / 2.0
  }
  ctx.save()
  if o.fill_line_dash is Some(dash) {
    ctx.set_line_dash(dash)
  }
  if o.fill_line_dash_offset is Some(offset) && truthy(offset) {
    ctx.set_line_dash_offset(offset)
  }
  ctx.set_stroke_style(o.fill.unwrap_or(""))
  ctx.set_line_width(fweight)
  draw_to_context(ctx, drawing, o.fixed_decimal_place_digits, "nonzero")
  ctx.restore()
}

///|
/// `+d.toFixed(digits)` when `digits` is set and not negative, else `d`.
fn round_to(d : Double, digits : Int32?) -> Double {
  match digits {
    Some(n) if n >= 0 => @jsmath.parse_float(@jsmath.to_fixed(d, n))
    _ => d
  }
}

///|
fn[C : Canvas2D] draw_to_context(
  ctx : C,
  drawing : @core.OpSet,
  fixed_decimals : Int32?,
  rule : String,
) -> Unit {
  ctx.begin_path()
  for item in drawing.ops {
    match item {
      Move(x, y) =>
        ctx.move_to(round_to(x, fixed_decimals), round_to(y, fixed_decimals))
      LineTo(x, y) =>
        ctx.line_to(round_to(x, fixed_decimals), round_to(y, fixed_decimals))
      BCurveTo(x1, y1, x2, y2, x, y) =>
        ctx.bezier_curve_to(
          round_to(x1, fixed_decimals),
          round_to(y1, fixed_decimals),
          round_to(x2, fixed_decimals),
          round_to(y2, fixed_decimals),
          round_to(x, fixed_decimals),
          round_to(y, fixed_decimals),
        )
    }
  }
  if drawing.kind is FillPath {
    ctx.fill(rule)
  } else {
    ctx.stroke()
  }
}

///|
/// rough.js' `RoughCanvas`: a generator that draws what it generates on a
/// canvas context. Every shape method returns the `Drawable` it painted.
pub struct RoughCanvas[C] {
  priv ctx : C
  priv generator : @core.Generator
}

///|
/// `rough.canvas(canvas, { options })`. `source` replaces `Math.random()`
/// as in `@core.Generator::new`.
pub fn[C] RoughCanvas::new(
  ctx : C,
  options? : @core.Options,
  source? : @random.RandomSource,
) -> RoughCanvas[C] {
  { ctx, generator: @core.Generator::new(options?, source?), }
}

///|
/// The generator the canvas draws with (`rc.generator`).
pub fn[C] RoughCanvas::generator(self : RoughCanvas[C]) -> @core.Generator {
  self.generator
}

///|
/// The context the canvas draws on.
pub fn[C] RoughCanvas::context(self : RoughCanvas[C]) -> C {
  self.ctx
}

///|
/// Paints an existing drawable (`rc.draw(drawable)`).
pub fn[C : Canvas2D] RoughCanvas::draw(
  self : RoughCanvas[C],
  drawable : @core.Drawable,
) -> Unit {
  draw(self.ctx, drawable)
}

///|
pub fn[C : Canvas2D] RoughCanvas::line(
  self : RoughCanvas[C],
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.line(x1, y1, x2, y2, options?)
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::rectangle(
  self : RoughCanvas[C],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.rectangle(x, y, width, height, options?)
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::ellipse(
  self : RoughCanvas[C],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.ellipse(x, y, width, height, options?)
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::circle(
  self : RoughCanvas[C],
  x : Double,
  y : Double,
  diameter : Double,
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.circle(x, y, diameter, options?)
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::linear_path(
  self : RoughCanvas[C],
  points : Array[(Double, Double)],
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.linear_path(points, options?)
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::polygon(
  self : RoughCanvas[C],
  points : Array[(Double, Double)],
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.polygon(points, options?)
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::arc(
  self : RoughCanvas[C],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  start : Double,
  stop : Double,
  closed~ : Bool = false,
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.arc(
    x,
    y,
    width,
    height,
    start,
    stop,
    closed~,
    options?,
  )
  draw(self.ctx, d)
  d
}

///|
pub fn[C : Canvas2D] RoughCanvas::curve(
  self : RoughCanvas[C],
  points : Array[(Double, Double)],
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.curve(points, options?)
  draw(self.ctx, d)
  d
}

///|
/// Several curves drawn as one shape.
pub fn[C : Canvas2D] RoughCanvas::curves(
  self : RoughCanvas[C],
  points_list : Array[Array[(Double, Double)]],
  options? : @core.Options,
) -> @core.Drawable {
  let d = self.generator.curves(points_list, options?)
  draw(self.ctx, d)
  d
}

///|
/// Raises on malformed path data, like `Generator::path`.
pub fn[C : Canvas2D] RoughCanvas::path(
  self : RoughCanvas[C],
  d : StringView,
  options? : @core.Options,
) -> @core.Drawable raise @path_data.PathError {
  let drawable = self.generator.path(d, options?)
  draw(self.ctx, drawable)
  drawable
}
