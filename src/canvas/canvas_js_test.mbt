// Tests of the js binding. They run only on js: they need a JavaScript object
// to stand in for a canvas context.

///|
/// A context that writes each call and property assignment as one line, the
/// way `@canvas.Event::describe` does.
extern "js" fn fake_context() -> @canvas.JsContext =
  #| () => {
  #|   const lines = []
  #|   const methods = ['save', 'restore', 'beginPath', 'moveTo', 'lineTo', 'bezierCurveTo', 'stroke', 'fill', 'setLineDash']
  #|   const ctx = { lines }
  #|   for (const m of methods) ctx[m] = (...a) => lines.push([m, ...a].join(' '))
  #|   for (const p of ['strokeStyle', 'fillStyle', 'lineWidth', 'lineDashOffset']) {
  #|     Object.defineProperty(ctx, p, { set: (v) => lines.push('set ' + p + ' ' + v) })
  #|   }
  #|   return ctx
  #| }

///|
extern "js" fn context_lines(ctx : @canvas.JsContext) -> String =
  #| (ctx) => ctx.lines.join('\n')

///|
test "the js binding makes the calls the recorder records" {
  let options = @core.Options::new(
    seed=8,
    fill="teal",
    fill_style=Zigzag,
    hachure_gap=9.0,
    stroke_line_dash=[5.0, 3.0],
    stroke_line_dash_offset=2.0,
    fill_line_dash=[2.0],
    fixed_decimal_place_digits=2,
  )
  for shape in ["rectangle", "ellipse", "polygon", "path"] {
    let generator = @core.Generator::new(options~)
    let drawable = match shape {
      "rectangle" => generator.rectangle(10.0, 10.0, 90.0, 60.0)
      "ellipse" => generator.ellipse(60.0, 50.0, 90.0, 60.0)
      "polygon" => generator.polygon([(0.0, 0.0), (80.0, 10.0), (40.0, 70.0)])
      _ =>
        generator.path("M 0 0 C 30 -20 60 40 90 10 L 50 60 Z") catch {
          _ => fail("bad path")
        }
    }
    let ctx = fake_context()
    @canvas.draw(ctx, drawable)
    let recorder = @canvas.Recorder::new()
    @canvas.draw(recorder, drawable)
    let expected = recorder.events.map(fn(e) { e.describe() }).join("\n")
    assert_true(expected.length() > 100, msg=shape)
    assert_eq(context_lines(ctx), expected, msg=shape)
  }
}

///|
test "RoughCanvas works with the js context" {
  let ctx = fake_context()
  let rc = @canvas.RoughCanvas::new(ctx, options=@core.Options::new(seed=3))
  ignore(rc.line(0.0, 0.0, 50.0, 20.0))
  let lines = context_lines(ctx).split("\n").to_array()
  assert_eq(lines[0], "save")
  assert_eq(lines[1], "set strokeStyle #000")
  assert_eq(lines[2], "set lineWidth 1")
  assert_eq(lines[3], "beginPath")
  assert_eq(lines[lines.length() - 2], "stroke")
  assert_eq(lines[lines.length() - 1], "restore")
}
