// Runs the drawable fixtures written by scripts/gen_fixtures.mjs
// (see `drawableCase` there for the entry format).

///|
fn set_code(kind : @core.OpSetType) -> String {
  match kind {
    Path => "P"
    FillPath => "F"
    FillSketch => "S"
  }
}

///|
fn op_code(op : @core.Op) -> String {
  match op {
    Move(_, _) => "m"
    LineTo(_, _) => "l"
    BCurveTo(_, _, _, _, _, _) => "c"
  }
}

///|
/// Compares one drawable fixture entry, drawn with a fresh generator.
fn run_drawable_fixture(
  stats : @fixture.ErrorStats,
  index : Int32,
  entry : String,
) -> Unit raise {
  let f = @fixture.fields(entry)
  let (generator, source) = @shapecase.fixture_generator(f[3])
  check_drawable(stats, "case \{index}", f, generator, source)
}

///|
/// Draws the fixture's shape with `generator` and compares the result,
/// including the random numbers drawn so far from `source`.
fn check_drawable(
  stats : @fixture.ErrorStats,
  name : String,
  f : Array[StringView],
  generator : @core.Generator,
  source : @random.RandomSource,
) -> Unit raise {
  let shape = f[0]
  let label = "\{name} (\{shape} \{f[2]})"
  let options = @shapecase.decode_options(f[2])
  if f[4] == "error" {
    let tag = try @shapecase.call_shape(generator, shape, f[1], options) catch {
      @path_data.InvalidCharacter(_) => "token"
      @path_data.ParamNotANumber(mode, text) => "param:\{mode},\{text}"
      @path_data.EndedShort => "short"
      @path_data.NumberAfterClose => "after-close"
      e => raise e
    } noraise {
      _ => "ok"
    }
    assert_eq(tag, f[5].to_owned(), msg=label)
    return
  }
  assert_eq(f[4].to_owned(), "ok", msg=label)
  let drawable = @shapecase.call_shape(generator, shape, f[1], options)
  assert_eq(drawable.shape.name(), f[5].to_owned(), msg="\{label}: shape")
  let expected_sets = if f[6].length() == 0 {
    []
  } else {
    f[6].split(";").to_array()
  }
  // Op types first: they must match exactly.
  let actual_kinds = drawable.sets.map(fn(s) { set_code(s.kind) }).join("")
  let expected_kinds = expected_sets.map(fn(s) { s[0:1].to_owned() }).join("")
  assert_eq(actual_kinds, expected_kinds, msg="\{label}: op set types")
  for i, expected in expected_sets {
    let set = drawable.sets[i]
    let ops = if expected.length() > 2 {
      expected[2:].split(",").to_array()
    } else {
      []
    }
    let actual_codes = set.ops.map(op_code).join("")
    let expected_codes = ops.map(fn(op) { op[0:1].to_owned() }).join("")
    assert_eq(
      actual_codes,
      expected_codes,
      msg="\{label}: op types of set \{i}",
    )
    for j, op in ops {
      let expected_data = @fixture.hex_list(op[2:])
      let data = set.ops[j].data()
      for k, e in expected_data {
        if !stats.record(data[k], e) {
          fail("\{label}: set \{i} op \{j} value \{k}: \{data[k]} vs \{e}")
        }
      }
    }
  }
  assert_eq(
    source.seeded_calls(),
    @string.parse_int(f[7]),
    msg="\{label}: seeded random numbers drawn",
  )
  assert_eq(
    source.fallback_calls(),
    @string.parse_int(f[8]),
    msg="\{label}: Math.random() numbers drawn",
  )
}

///|
fn run_drawable_fixtures(name : String, fixtures : Array[String]) -> Unit raise {
  let stats = @fixture.ErrorStats::new(name)
  for i, entry in fixtures {
    run_drawable_fixture(stats, i, entry)
  }
  println(stats.summary())
}

///|
test "every shape with stroke, solid and hachure fills matches rough.js" {
  run_drawable_fixtures("core shapes", shape_fixtures)
}

///|
test "all seven fill styles on every fillable shape match rough.js" {
  run_drawable_fixtures("core fills", fill_fixtures)
}

///|
test "500+ random shape and option combinations match rough.js" {
  assert_true(random_fixtures.length() >= 500)
  run_drawable_fixtures("core random", random_fixtures)
}

///|
test "edge cases match rough.js" {
  run_drawable_fixtures("core edge cases", edge_fixtures)
}

///|
test "calls on one generator share its default options like rough.js" {
  let stats = @fixture.ErrorStats::new("core sequences")
  for i, sequence in sequence_fixtures {
    let steps = sequence.split("~").to_array()
    let (generator, source) = @shapecase.fixture_generator(
      @fixture.fields(steps[0].to_owned())[3],
    )
    for j, step in steps {
      let f = @fixture.fields(step.to_owned())
      check_drawable(stats, "sequence \{i} step \{j}", f, generator, source)
    }
  }
  println(stats.summary())
}
