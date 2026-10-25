// Runs the drawable fixtures written by scripts/gen_fixtures.mjs
// (see `drawableCase` there for the entry format).

///|
/// The Math.random replacement the fixture generator installs.
const FALLBACK_SEED : Int32 = 1234567

///|
fn decode_options(s : StringView) -> @core.Options? raise {
  if s == "-" {
    return None
  }
  let mut o = @core.Options::new()
  if s.length() == 0 {
    return Some(o)
  }
  for pair in s.split(";") {
    let parts = pair.split(":").to_array()
    let name = parts[0]
    let value = parts[2]
    let n = fn() { @fixture.hex_to_double(value) }
    let a = fn() { @fixture.hex_list(value) }
    let b = value == "1"
    let s = value.to_owned()
    o = match name {
      "maxRandomnessOffset" => { ..o, max_randomness_offset: Some(n()), }
      "roughness" => { ..o, roughness: Some(n()), }
      "bowing" => { ..o, bowing: Some(n()), }
      "stroke" => { ..o, stroke: Some(s), }
      "strokeWidth" => { ..o, stroke_width: Some(n()), }
      "curveFitting" => { ..o, curve_fitting: Some(n()), }
      "curveTightness" => { ..o, curve_tightness: Some(n()), }
      "curveStepCount" => { ..o, curve_step_count: Some(n()), }
      "fill" => { ..o, fill: Some(s), }
      "fillStyle" =>
        { ..o, fill_style: Some(@core.FillStyle::from_name(value)), }
      "fillWeight" => { ..o, fill_weight: Some(n()), }
      "hachureAngle" => { ..o, hachure_angle: Some(n()), }
      "hachureGap" => { ..o, hachure_gap: Some(n()), }
      "simplification" => { ..o, simplification: Some(n()), }
      "dashOffset" => { ..o, dash_offset: Some(n()), }
      "dashGap" => { ..o, dash_gap: Some(n()), }
      "zigzagOffset" => { ..o, zigzag_offset: Some(n()), }
      "seed" => { ..o, seed: Some(@string.parse_int(value)), }
      "strokeLineDash" => { ..o, stroke_line_dash: Some(a()), }
      "strokeLineDashOffset" => { ..o, stroke_line_dash_offset: Some(n()), }
      "fillLineDash" => { ..o, fill_line_dash: Some(a()), }
      "fillLineDashOffset" => { ..o, fill_line_dash_offset: Some(n()), }
      "disableMultiStroke" => { ..o, disable_multi_stroke: Some(b), }
      "disableMultiStrokeFill" => { ..o, disable_multi_stroke_fill: Some(b), }
      "preserveVertices" => { ..o, preserve_vertices: Some(b), }
      "fixedDecimalPlaceDigits" =>
        { ..o, fixed_decimal_place_digits: Some(@string.parse_int(value)), }
      "fillShapeRoughnessGain" => { ..o, fill_shape_roughness_gain: Some(n()), }
      _ => fail("unknown option \{name}")
    }
  }
  Some(o)
}

///|
fn decode_point_list(s : StringView) -> Array[(Double, Double)] {
  let v = @fixture.hex_list(s)
  Array::makei(v.length() / 2, fn(i) { (v[2 * i], v[2 * i + 1]) })
}

///|
fn call_shape(
  generator : @core.Generator,
  shape : StringView,
  args : StringView,
  options : @core.Options?,
) -> @core.Drawable raise {
  let v = fn() { @fixture.hex_list(args) }
  match shape {
    "line" => {
      let a = v()
      generator.line(a[0], a[1], a[2], a[3], options?)
    }
    "rectangle" => {
      let a = v()
      generator.rectangle(a[0], a[1], a[2], a[3], options?)
    }
    "ellipse" => {
      let a = v()
      generator.ellipse(a[0], a[1], a[2], a[3], options?)
    }
    "circle" => {
      let a = v()
      generator.circle(a[0], a[1], a[2], options?)
    }
    "linearPath" => generator.linear_path(decode_point_list(args), options?)
    "polygon" => generator.polygon(decode_point_list(args), options?)
    "arc" => {
      let a = v()
      generator.arc(
        a[0],
        a[1],
        a[2],
        a[3],
        a[4],
        a[5],
        closed=a[6] != 0.0,
        options?,
      )
    }
    "curve" => generator.curve(decode_point_list(args), options?)
    "curves" => {
      let list = if args.length() == 0 {
        []
      } else {
        args.split(";").map(decode_point_list).to_array()
      }
      generator.curves(list, options?)
    }
    "path" => generator.path(args, options?)
    _ => fail("unknown shape \{shape}")
  }
}

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
/// A generator configured like the fixture's `rough.generator(config)`.
fn fixture_generator(
  config : StringView,
) -> (@core.Generator, @random.RandomSource) raise {
  let source = @random.RandomSource::park_miller(FALLBACK_SEED)
  let generator = match decode_options(config) {
    Some(config) => @core.Generator::new(options=config, source~)
    None => @core.Generator::new(source~)
  }
  (generator, source)
}

///|
/// Compares one drawable fixture entry, drawn with a fresh generator.
fn run_drawable_fixture(
  stats : @fixture.ErrorStats,
  index : Int32,
  entry : String,
) -> Unit raise {
  let f = @fixture.fields(entry)
  let (generator, source) = fixture_generator(f[3])
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
  let options = decode_options(f[2])
  if f[4] == "error" {
    let tag = try call_shape(generator, shape, f[1], options) catch {
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
  let drawable = call_shape(generator, shape, f[1], options)
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
    let (generator, source) = fixture_generator(
      @fixture.fields(steps[0].to_owned())[3],
    )
    for j, step in steps {
      let f = @fixture.fields(step.to_owned())
      check_drawable(stats, "sequence \{i} step \{j}", f, generator, source)
    }
  }
  println(stats.summary())
}
