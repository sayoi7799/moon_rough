// A Canvas2D that writes the calls down instead of drawing.

///|
/// One call or property assignment on a canvas context.
pub(all) enum Event {
  Save
  Restore
  BeginPath
  MoveTo(Double, Double)
  LineTo(Double, Double)
  BezierCurveTo(Double, Double, Double, Double, Double, Double)
  Stroke
  Fill(String)
  SetStrokeStyle(String)
  SetFillStyle(String)
  SetLineWidth(Double)
  SetLineDash(Array[Double])
  SetLineDashOffset(Double)
} derive(Eq, Debug)

///|
/// The event as rough.js' source would spell it, e.g. `moveTo 1 2` or
/// `set strokeStyle red`; the numbers are written as JavaScript writes
/// them and the dash list is comma separated.
pub fn Event::describe(self : Event) -> String {
  match self {
    Save => "save"
    Restore => "restore"
    BeginPath => "beginPath"
    MoveTo(x, y) => "moveTo \{x} \{y}"
    LineTo(x, y) => "lineTo \{x} \{y}"
    BezierCurveTo(x1, y1, x2, y2, x, y) =>
      "bezierCurveTo \{x1} \{y1} \{x2} \{y2} \{x} \{y}"
    Stroke => "stroke"
    Fill(rule) => "fill \{rule}"
    SetStrokeStyle(s) => "set strokeStyle \{s}"
    SetFillStyle(s) => "set fillStyle \{s}"
    SetLineWidth(w) => "set lineWidth \{w}"
    SetLineDash(dash) =>
      "setLineDash \{dash.map(fn(d) { d.to_string() }).join(",")}"
    SetLineDashOffset(o) => "set lineDashOffset \{o}"
  }
}

///|
/// Records every call it receives, in order.
pub struct Recorder {
  events : Array[Event]
}

///|
pub fn Recorder::new() -> Recorder {
  { events: [], }
}

///|
pub impl Canvas2D for Recorder with fn save(self) {
  self.events.push(Save)
}

///|
pub impl Canvas2D for Recorder with fn restore(self) {
  self.events.push(Restore)
}

///|
pub impl Canvas2D for Recorder with fn begin_path(self) {
  self.events.push(BeginPath)
}

///|
pub impl Canvas2D for Recorder with fn move_to(self, x, y) {
  self.events.push(MoveTo(x, y))
}

///|
pub impl Canvas2D for Recorder with fn line_to(self, x, y) {
  self.events.push(LineTo(x, y))
}

///|
pub impl Canvas2D for Recorder with fn bezier_curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.events.push(BezierCurveTo(x1, y1, x2, y2, x, y))
}

///|
pub impl Canvas2D for Recorder with fn stroke(self) {
  self.events.push(Stroke)
}

///|
pub impl Canvas2D for Recorder with fn fill(self, rule) {
  self.events.push(Fill(rule))
}

///|
pub impl Canvas2D for Recorder with fn set_stroke_style(self, style) {
  self.events.push(SetStrokeStyle(style))
}

///|
pub impl Canvas2D for Recorder with fn set_fill_style(self, style) {
  self.events.push(SetFillStyle(style))
}

///|
pub impl Canvas2D for Recorder with fn set_line_width(self, width) {
  self.events.push(SetLineWidth(width))
}

///|
pub impl Canvas2D for Recorder with fn set_line_dash(self, dash) {
  self.events.push(SetLineDash(dash))
}

///|
pub impl Canvas2D for Recorder with fn set_line_dash_offset(self, offset) {
  self.events.push(SetLineDashOffset(offset))
}
