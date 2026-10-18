///|
fn decode_points(s : StringView) -> Array[@geometry.Point] {
  let v = @fixture.hex_list(s)
  Array::makei(v.length() / 2, fn(i) {
    @geometry.Point::new(v[2 * i], v[2 * i + 1])
  })
}

///|
fn decode_optional(s : StringView) -> Double? {
  if s == "-" {
    None
  } else {
    Some(@fixture.hex_to_double(s))
  }
}

///|
/// The identity signature `gen_fixtures.mjs` writes (see `identity` there).
fn identity(
  outputs : Array[@geometry.Point],
  inputs : Array[@geometry.Point],
) -> String {
  outputs
  .mapi(fn(k, p) {
    for i, q in inputs {
      if physical_equal(p, q) {
        return "i\{i}"
      }
    }
    for o in 0..<k {
      if physical_equal(p, outputs[o]) {
        return "o\{o}"
      }
    }
    "n"
  })
  .join(",")
}

///|
fn check_points(
  stats : @fixture.ErrorStats,
  what : String,
  actual : Array[@geometry.Point],
  expected : Array[@geometry.Point],
) -> Unit raise {
  assert_eq(actual.length(), expected.length(), msg="\{what}: point count")
  for i, e in expected {
    let a = actual[i]
    assert_true(
      stats.record(a.x, e.x) && stats.record(a.y, e.y),
      msg="\{what}: point \{i}: (\{a.x}, \{a.y}) vs (\{e.x}, \{e.y})",
    )
  }
}

///|
test "points_on_bezier_curves matches points-on-curve" {
  let stats = @fixture.ErrorStats::new("curve points_on_bezier_curves")
  for n, entry in bezier_fixtures {
    let f = @fixture.fields(entry)
    let input = decode_points(f[0])
    let tolerance = @fixture.hex_to_double(f[1])
    let out = match decode_optional(f[2]) {
      Some(distance) =>
        @curve.points_on_bezier_curves(input, tolerance~, distance~)
      None => @curve.points_on_bezier_curves(input, tolerance~)
    }
    check_points(stats, "bezier #\{n}", out, decode_points(f[3]))
    assert_eq(
      identity(out, input),
      f[4].to_owned(),
      msg="bezier #\{n} identity",
    )
  }
  println(stats.summary())
}

///|
test "curve_to_bezier matches points-on-curve" {
  let stats = @fixture.ErrorStats::new("curve curve_to_bezier")
  for n, entry in curve_to_bezier_fixtures {
    let f = @fixture.fields(entry)
    let input = decode_points(f[0])
    let curve_tightness = @fixture.hex_to_double(f[1])
    let out = @curve.curve_to_bezier(input, curve_tightness~)
    check_points(stats, "curve_to_bezier #\{n}", out, decode_points(f[2]))
    assert_eq(identity(out, input), f[3].to_owned())
  }
  println(stats.summary())
}

///|
test "curve_to_bezier needs three points" {
  try
    @curve.curve_to_bezier([
      @geometry.Point::new(0.0, 0.0),
      @geometry.Point::new(1.0, 1.0),
    ])
  catch {
    @curve.CurveTooShort => ()
  } noraise {
    _ => fail("expected CurveTooShort")
  }
}

///|
test "simplify matches points-on-curve" {
  let stats = @fixture.ErrorStats::new("curve simplify")
  for n, entry in simplify_fixtures {
    let f = @fixture.fields(entry)
    let input = decode_points(f[0])
    let out = @curve.simplify(input, @fixture.hex_to_double(f[1]))
    check_points(stats, "simplify #\{n}", out, decode_points(f[2]))
    assert_eq(identity(out, input), f[3].to_owned(), msg="simplify #\{n}")
  }
  println(stats.summary())
}

///|
test "points_on_path matches points-on-path" {
  let stats = @fixture.ErrorStats::new("curve points_on_path")
  for entry in points_on_path_fixtures {
    let f = @fixture.fields(entry)
    let d = f[0]
    let sets = match (decode_optional(f[1]), decode_optional(f[2])) {
      (Some(tolerance), Some(distance)) =>
        @curve.points_on_path(d, tolerance~, distance~)
      (Some(tolerance), None) => @curve.points_on_path(d, tolerance~)
      (None, Some(distance)) => @curve.points_on_path(d, distance~)
      (None, None) => @curve.points_on_path(d)
    }
    let expected = if f[3].length() == 0 {
      []
    } else {
      f[3].split(";").map(decode_points).to_array()
    }
    assert_eq(sets.length(), expected.length(), msg="\{d}: set count")
    for i, e in expected {
      check_points(stats, "\{d} set \{i}", sets[i], e)
    }
    let flat = sets.iter().flat_map(fn(s) { s.iter() }).to_array()
    assert_eq(identity(flat, []), f[4].to_owned(), msg="\{d}: identity")
  }
  println(stats.summary())
}
