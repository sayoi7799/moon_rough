///|
fn check_bits(
  stats : @fixture.ErrorStats,
  what : String,
  x : Double,
  actual : Double,
  expected : Double,
) -> Unit raise {
  ignore(stats.record(actual, expected))
  if !@fixture.same(actual, expected) {
    fail("\{what}(\{x}) = \{actual}, Node gives \{expected}")
  }
}

///|
test "sin, cos, tan, atan and asin are bit-identical to Node" {
  let stats = @fixture.ErrorStats::new("jsmath trig")
  for entry in trig_fixtures {
    let v = @fixture.hex_list(entry)
    let x = v[0]
    check_bits(stats, "sin", x, @jsmath.sin(x), v[1])
    check_bits(stats, "cos", x, @jsmath.cos(x), v[2])
    check_bits(stats, "tan", x, @jsmath.tan(x), v[3])
    check_bits(stats, "atan", x, @jsmath.atan(x), v[4])
    check_bits(stats, "asin", v[6], @jsmath.asin(v[6]), v[5])
  }
  println(stats.summary())
}

///|
test "round matches Math.round" {
  for entry in round_fixtures {
    let v = @fixture.hex_list(entry)
    let r = @jsmath.round(v[0])
    assert_true(
      @fixture.same(r, v[1]) &&
      (r != 0.0 || r.reinterpret_as_uint64() == v[1].reinterpret_as_uint64()),
      msg="round(\{v[0]}) = \{r}, Node gives \{v[1]}",
    )
  }
}

///|
test "to_fixed matches Number.prototype.toFixed" {
  for entry in to_fixed_fixtures {
    let parts = @fixture.fields(entry)
    let x = @fixture.hex_to_double(parts[0])
    let digits = @string.parse_int(parts[1])
    assert_eq(
      @jsmath.to_fixed(x, digits),
      parts[2].to_owned(),
      msg="toFixed(\{x}, \{digits})",
    )
  }
}

///|
test "number_to_string matches String(number)" {
  for entry in to_string_fixtures {
    let parts = @fixture.fields(entry)
    let x = @fixture.hex_to_double(parts[0])
    assert_eq(@jsmath.number_to_string(x), parts[1].to_owned())
  }
}

///|
test "parse_float matches parseFloat" {
  for entry in parse_float_fixtures {
    let parts = @fixture.fields(entry)
    let expected = @fixture.hex_to_double(parts[1])
    let actual = @jsmath.parse_float(parts[0])
    assert_true(
      actual.reinterpret_as_uint64() == expected.reinterpret_as_uint64(),
      msg="parse_float(\{parts[0]}) = \{actual}, Node gives \{expected}",
    )
  }
}

///|
test "min and max match Math.min and Math.max, including -0 and NaN" {
  for entry in min_max_fixtures {
    let v = @fixture.hex_list(entry)
    let lo = @jsmath.min(v[0], v[1])
    let hi = @jsmath.max(v[0], v[1])
    assert_true(
      @fixture.same(lo, v[2]) &&
      (
        lo.is_nan() ||
        lo.reinterpret_as_uint64() == v[2].reinterpret_as_uint64()
      ),
      msg="min(\{v[0]}, \{v[1]})",
    )
    assert_true(
      @fixture.same(hi, v[3]) &&
      (
        hi.is_nan() ||
        hi.reinterpret_as_uint64() == v[3].reinterpret_as_uint64()
      ),
      msg="max(\{v[0]}, \{v[1]})",
    )
  }
}

///|
test "Math.pow(x, 2) is x * x" {
  for entry in pow2_fixtures {
    let v = @fixture.hex_list(entry)
    assert_true(@fixture.same(v[0] * v[0], v[1]), msg="pow(\{v[0]}, 2)")
  }
}
