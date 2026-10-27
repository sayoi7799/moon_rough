// The benchmarks time the generation of shapes and paths from the inputs of
// cases.mbt. Here, what is made of those inputs is compared with what the
// official rough.js 4.6.6 makes of the same inputs (perf_fixtures_test.mbt,
// written by scripts/gen_fixtures.mjs): the number of op sets and ops and the
// sum of every number, bit for bit. If these hold, the two sides of the
// comparison do exactly the same work.

///|
struct Expected {
  a : Int32
  b : Int32
  sum : Double
}

///|
fn expected(name : String) -> Expected {
  for entry in perf_fixtures {
    let f = @fixture.fields(entry)
    if f[0] == name {
      return {
        a: @string.parse_int(f[1]) catch {
          _ => abort("bad number")
        },
        b: @string.parse_int(f[2]) catch {
          _ => abort("bad number")
        },
        sum: @fixture.hex_to_double(f[3]),
      }
    }
  }
  abort("no fixture named \{name}")
}

///|
/// A generator whose Math.random replacement is the sequence the fixture
/// generator installs, which only the dots fill uses.
fn generator() -> @core.Generator {
  @core.Generator::new(
    source=@random.RandomSource::park_miller(@shapecase.FALLBACK_SEED),
  )
}

///|
fn check(name : String, drawables : Array[@core.Drawable]) -> Unit raise {
  let want = expected(name)
  let got = @perf.checksum(drawables)
  assert_eq(got.sets, want.a, msg="\{name}: op sets")
  assert_eq(got.ops, want.b, msg="\{name}: ops")
  assert_true(
    @fixture.double_to_hex(got.sum) == @fixture.double_to_hex(want.sum),
    msg="\{name}: the numbers add up to \{got.sum}, rough.js makes \{want.sum}",
  )
}

///|
test "10,000 random shapes are what rough.js makes of them" {
  let g = generator()
  let cases = @perf.random_cases(@perf.SHAPES, @perf.SHAPE_SEED)
  check("random_shapes", cases.map(fn(c) { c.generate(g) }))
}

///|
test "dots fills are what rough.js makes of them" {
  let g = generator()
  let cases = @perf.random_cases(@perf.DOTS, @perf.DOTS_SEED, dots=true)
  check("dots", cases.map(fn(c) { c.generate(g) }))
}

///|
test "the complex path is parsed like path-data-parser" {
  let d = @perf.complex_path(@perf.SEGMENTS, @perf.PATH_SEED)
  let segments = @path_data.normalize(
    @path_data.absolutize(@path_data.parse_path(d)),
  )
  let want = expected("parse")
  let mut values = 0
  let mut sum = 0.0
  for s in segments {
    for x in s.data {
      values += 1
      sum += x
    }
  }
  assert_eq(segments.length(), want.a)
  assert_eq(values, want.b)
  assert_eq(@fixture.double_to_hex(sum), @fixture.double_to_hex(want.sum))
}

///|
test "points_on_path of the complex path is what points-on-path gives" {
  let d = @perf.complex_path(@perf.SEGMENTS, @perf.PATH_SEED)
  let sets = @curve.points_on_path(d, tolerance=1.0, distance=1.0)
  let want = expected("points_on_path")
  let mut points = 0
  let mut sum = 0.0
  for set in sets {
    for p in set {
      points += 1
      sum += p.x + p.y
    }
  }
  assert_eq(sets.length(), want.a)
  assert_eq(points, want.b)
  assert_eq(@fixture.double_to_hex(sum), @fixture.double_to_hex(want.sum))
}

///|
test "the complex path filled in three styles is what rough.js makes of it" {
  let d = @perf.complex_path(@perf.SEGMENTS, @perf.PATH_SEED)
  let g = generator()
  for
    style in [
      ("hachure", @core.Hachure),
      ("solid", Solid),
      ("cross-hatch", CrossHatch),
    ] {
    let drawable = g.path(
      d,
      options=@core.Options::new(
        seed=1,
        fill="#e76f51",
        fill_style=style.1,
        hachure_gap=8.0,
      ),
    )
    check("path_\{style.0}", [drawable])
  }
}

///|
test "the SVG of 10,000 shapes has the length rough.js' path data gives" {
  for fixed in [None, Some(2)] {
    let g = generator()
    let cases = match fixed {
      Some(digits) =>
        @perf.random_cases(@perf.SHAPES, @perf.SHAPE_SEED, fixed_digits=digits)
      None => @perf.random_cases(@perf.SHAPES, @perf.SHAPE_SEED)
    }
    let mut length = 0
    for c in cases {
      length += @svg.drawable_to_svg(c.generate(g)).length()
    }
    let name = if fixed is Some(_) { "svg_fixed2" } else { "svg_plain" }
    assert_eq(length, expected(name).a, msg=name)
  }
}
