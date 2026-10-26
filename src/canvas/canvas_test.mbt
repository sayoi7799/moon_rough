///|
/// The event as `gen_fixtures.mjs` writes it: numbers as hex bit patterns.
fn event_text(event : @canvas.Event) -> String {
  let h = @fixture.double_to_hex
  match event {
    Save => "save"
    Restore => "restore"
    BeginPath => "beginPath"
    MoveTo(x, y) => "moveTo \{h(x)} \{h(y)}"
    LineTo(x, y) => "lineTo \{h(x)} \{h(y)}"
    BezierCurveTo(x1, y1, x2, y2, x, y) =>
      "bezierCurveTo \{h(x1)} \{h(y1)} \{h(x2)} \{h(y2)} \{h(x)} \{h(y)}"
    Stroke => "stroke"
    Fill(rule) => "fill \{rule}"
    SetStrokeStyle(s) => "set strokeStyle \{s}"
    SetFillStyle(s) => "set fillStyle \{s}"
    SetLineWidth(w) => "set lineWidth \{h(w)}"
    SetLineDash(dash) => "setLineDash \{dash.map(h).join(" ")}"
    SetLineDashOffset(o) => "set lineDashOffset \{h(o)}"
  }
}

///|
test "draw makes the same canvas calls as rough.js, in the same order" {
  assert_true(canvas_fixtures.length() > 400)
  let mut calls = 0
  for i, entry in canvas_fixtures {
    let f = @fixture.fields(entry)
    let label = "case \{i} (\{f[0]} \{f[2]})"
    let (generator, _) = @shapecase.fixture_generator(f[3])
    let drawable = @shapecase.call_shape(
      generator,
      f[0],
      f[1],
      @shapecase.decode_options(f[2]),
    )
    let recorder = @canvas.Recorder::new()
    @canvas.draw(recorder, drawable)
    let actual = recorder.events.map(event_text)
    // No op set (stroke none, no fill) means no call at all.
    let expected = if f[4].length() == 0 {
      []
    } else {
      f[4].split(";").map(fn(s) { s.to_owned() }).to_array()
    }
    assert_eq(
      actual.length(),
      expected.length(),
      msg="\{label}: number of calls",
    )
    for j, e in expected {
      if actual[j] != e {
        fail("\{label}: call \{j} is `\{actual[j]}`, rough.js made `\{e}`")
      }
    }
    calls += actual.length()
  }
  println(
    "[canvas] \{canvas_fixtures.length()} drawables, \{calls} calls, all identical to rough.js",
  )
}

///|
test "RoughCanvas draws what its generator generates" {
  let options = @core.Options::new(
    seed=21,
    fill="red",
    fill_style=CrossHatch,
    hachure_gap=9.0,
    stroke_line_dash=[4.0, 2.0],
  )
  let recorder = @canvas.Recorder::new()
  let rc = @canvas.RoughCanvas::new(recorder, options~)
  let drawn = rc.ellipse(60.0, 50.0, 80.0, 60.0)
  // The same shape from a separate generator with the same options.
  let reference = @core.Generator::new(options~).ellipse(60.0, 50.0, 80.0, 60.0)
  let expected = @canvas.Recorder::new()
  @canvas.draw(expected, reference)
  assert_eq(recorder.events, expected.events)
  assert_eq(drawn.sets.length(), reference.sets.length())
  assert_true(recorder.events.length() > 20)
}

///|
test "every RoughCanvas shape method draws its drawable" {
  let rc = @canvas.RoughCanvas::new(
    @canvas.Recorder::new(),
    options=@core.Options::new(seed=5),
  )
  let sets = [
    rc.line(0.0, 0.0, 10.0, 10.0).sets.length(),
    rc.rectangle(0.0, 0.0, 10.0, 10.0).sets.length(),
    rc.ellipse(5.0, 5.0, 10.0, 8.0).sets.length(),
    rc.circle(5.0, 5.0, 10.0).sets.length(),
    rc.linear_path([(0.0, 0.0), (5.0, 8.0), (10.0, 0.0)]).sets.length(),
    rc.polygon([(0.0, 0.0), (5.0, 8.0), (10.0, 0.0)]).sets.length(),
    rc.arc(5.0, 5.0, 10.0, 10.0, 0.0, 3.0, closed=true).sets.length(),
    rc.curve([(0.0, 0.0), (5.0, 8.0), (10.0, 0.0), (15.0, 8.0)]).sets.length(),
    rc.curves([[(0.0, 0.0), (5.0, 8.0)], [(0.0, 5.0), (5.0, 9.0)]]).sets.length(),
    rc.path("M 0 0 L 10 10 Z").sets.length(),
  ]
  assert_eq(sets.length(), 10)
  // Each op set is drawn between a save and a restore, ending in a stroke.
  let total = sets.fold(init=0, fn(acc, n) { acc + n })
  let events = rc.context().events
  assert_eq(events.filter(fn(e) { e is Stroke }).length(), total)
  assert_eq(events.filter(fn(e) { e is Save }).length(), total)
  assert_eq(events.filter(fn(e) { e is Restore }).length(), total)
}

///|
test "malformed path data raises and draws nothing" {
  let rc = @canvas.RoughCanvas::new(@canvas.Recorder::new())
  try rc.path("M 10 10 L") catch {
    @path_data.EndedShort => ()
    _ => fail("expected EndedShort")
  } noraise {
    _ => fail("expected an error")
  }
  assert_eq(rc.context().events.length(), 0)
}
