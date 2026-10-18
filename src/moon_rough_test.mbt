///|
test "the README example works" {
  let gen = @moon_rough.generator(
    source=@moon_rough.RandomSource::park_miller(1),
  )
  let rect = gen.rectangle(
    10.0,
    10.0,
    200.0,
    100.0,
    options=@moon_rough.Options::new(
      seed=42,
      fill="#e66",
      fill_style=CrossHatch,
      roughness=1.5,
    ),
  )
  // A fill sketch and the outline.
  assert_eq(rect.sets.map(fn(s) { s.kind.name() }), ["fillSketch", "path"])
  let svg = @moon_rough.drawable_to_svg(rect)
  assert_true(svg.has_prefix("<g><path d=\"M"))
  // The same seed gives the same drawing.
  let again = gen.rectangle(
    10.0,
    10.0,
    200.0,
    100.0,
    options=@moon_rough.Options::new(
      seed=42,
      fill="#e66",
      fill_style=CrossHatch,
      roughness=1.5,
    ),
  )
  assert_eq(@moon_rough.drawable_to_svg(again), svg)
}

///|
test "path errors are reported" {
  let gen = @moon_rough.generator()
  let result = try gen.path("M 10 10 L") catch {
    @moon_rough.PathError::EndedShort => "ended short"
    _ => "other"
  } noraise {
    _ => "ok"
  }
  assert_eq(result, "ended short")
}
