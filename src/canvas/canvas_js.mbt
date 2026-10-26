// The js binding of Canvas2D: a CanvasRenderingContext2D (or anything with
// the same methods and properties).

///|
/// A JavaScript canvas 2D context. Values of this type come from JavaScript,
/// e.g. `canvas.getContext("2d")` passed to an exported function.
pub type JsContext

///|
extern "js" fn js_save(ctx : JsContext) -> Unit =
  #| (ctx) => ctx.save()

///|
extern "js" fn js_restore(ctx : JsContext) -> Unit =
  #| (ctx) => ctx.restore()

///|
extern "js" fn js_begin_path(ctx : JsContext) -> Unit =
  #| (ctx) => ctx.beginPath()

///|
extern "js" fn js_move_to(ctx : JsContext, x : Double, y : Double) -> Unit =
  #| (ctx, x, y) => ctx.moveTo(x, y)

///|
extern "js" fn js_line_to(ctx : JsContext, x : Double, y : Double) -> Unit =
  #| (ctx, x, y) => ctx.lineTo(x, y)

///|
extern "js" fn js_bezier_curve_to(
  ctx : JsContext,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
) -> Unit =
  #| (ctx, x1, y1, x2, y2, x, y) => ctx.bezierCurveTo(x1, y1, x2, y2, x, y)

///|
extern "js" fn js_stroke(ctx : JsContext) -> Unit =
  #| (ctx) => ctx.stroke()

///|
extern "js" fn js_fill(ctx : JsContext, rule : String) -> Unit =
  #| (ctx, rule) => ctx.fill(rule)

///|
extern "js" fn js_set_stroke_style(ctx : JsContext, style : String) -> Unit =
  #| (ctx, style) => { ctx.strokeStyle = style }

///|
extern "js" fn js_set_fill_style(ctx : JsContext, style : String) -> Unit =
  #| (ctx, style) => { ctx.fillStyle = style }

///|
extern "js" fn js_set_line_width(ctx : JsContext, width : Double) -> Unit =
  #| (ctx, width) => { ctx.lineWidth = width }

///|
extern "js" fn js_set_line_dash(
  ctx : JsContext,
  dash : FixedArray[Double],
) -> Unit =
  #| (ctx, dash) => ctx.setLineDash(dash)

///|
extern "js" fn js_set_line_dash_offset(
  ctx : JsContext,
  offset : Double,
) -> Unit =
  #| (ctx, offset) => { ctx.lineDashOffset = offset }

///|
pub impl Canvas2D for JsContext with fn save(self) {
  js_save(self)
}

///|
pub impl Canvas2D for JsContext with fn restore(self) {
  js_restore(self)
}

///|
pub impl Canvas2D for JsContext with fn begin_path(self) {
  js_begin_path(self)
}

///|
pub impl Canvas2D for JsContext with fn move_to(self, x, y) {
  js_move_to(self, x, y)
}

///|
pub impl Canvas2D for JsContext with fn line_to(self, x, y) {
  js_line_to(self, x, y)
}

///|
pub impl Canvas2D for JsContext with fn bezier_curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  js_bezier_curve_to(self, x1, y1, x2, y2, x, y)
}

///|
pub impl Canvas2D for JsContext with fn stroke(self) {
  js_stroke(self)
}

///|
pub impl Canvas2D for JsContext with fn fill(self, rule) {
  js_fill(self, rule)
}

///|
pub impl Canvas2D for JsContext with fn set_stroke_style(self, style) {
  js_set_stroke_style(self, style)
}

///|
pub impl Canvas2D for JsContext with fn set_fill_style(self, style) {
  js_set_fill_style(self, style)
}

///|
pub impl Canvas2D for JsContext with fn set_line_width(self, width) {
  js_set_line_width(self, width)
}

///|
pub impl Canvas2D for JsContext with fn set_line_dash(self, dash) {
  js_set_line_dash(self, FixedArray::from_array(dash))
}

///|
pub impl Canvas2D for JsContext with fn set_line_dash_offset(self, offset) {
  js_set_line_dash_offset(self, offset)
}
