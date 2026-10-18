// Inputs on which rough.js 4.6.6 never returns or throws, so there is no
// fixture to compare with. moon_rough must terminate on them; see the README,
// "Differences from rough.js".

///|
test "an arc with start == stop terminates (rough.js loops forever)" {
  let g = @core.Generator::new()
  let d = g.arc(
    50.0,
    50.0,
    80.0,
    60.0,
    1.0,
    1.0,
    closed=true,
    options=@core.Options::new(seed=1, fill="red"),
  )
  assert_eq(d.shape.name(), "arc")
  assert_true(d.sets.length() == 2)
}

///|
test "a filled polygon without points has no fill (rough.js throws)" {
  let g = @core.Generator::new()
  let d = g.polygon([], options=@core.Options::new(seed=1, fill="red"))
  assert_eq(d.sets.length(), 2)
  assert_eq(d.sets[0].kind, FillSketch)
  assert_eq(d.sets[0].ops.length(), 0)
  assert_eq(d.sets[1].ops.length(), 0)
}

///|
test "dashed and zigzag-line fills with a zero period terminate" {
  let g = @core.Generator::new()
  let dashed = g.rectangle(
    10.0,
    10.0,
    80.0,
    60.0,
    options=@core.Options::new(
      seed=2,
      fill="red",
      fill_style=Dashed,
      dash_offset=0.0,
      dash_gap=0.0,
    ),
  )
  assert_eq(dashed.sets[0].ops.length(), 0)
  let zigzag = g.rectangle(
    10.0,
    10.0,
    80.0,
    60.0,
    options=@core.Options::new(
      seed=3,
      fill="red",
      fill_style=ZigzagLine,
      zigzag_offset=0.0,
    ),
  )
  assert_eq(zigzag.sets[0].ops.length(), 0)
}

///|
test "malformed path data raises instead of throwing or hanging" {
  let g = @core.Generator::new()
  for d in ["M 10 10 Z 5", "M 10 10 L", "M 10 10 L Z", "M 10 # 10"] {
    let result = try g.path(d) catch {
      _ => "error"
    } noraise {
      _ => "ok"
    }
    assert_eq(result, "error", msg=d)
  }
}

///|
test "the empty path has no op sets" {
  let g = @core.Generator::new()
  let d = g.path("", options=@core.Options::new(seed=1, fill="red"))
  assert_eq(d.sets.length(), 0)
}
