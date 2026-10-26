// Decodes the shape cases that scripts/gen_fixtures.mjs writes (shape name,
// arguments and options as bit-exact hex) and draws them with a Generator.
// Shared by the tests of every package that compares with rough.js output.

///|
/// The Math.random replacement the fixture generator installs.
pub const FALLBACK_SEED : Int32 = 1234567

///|
pub fn decode_options(s : StringView) -> @core.Options? raise {
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
pub fn decode_point_list(s : StringView) -> Array[(Double, Double)] {
  let v = @fixture.hex_list(s)
  Array::makei(v.length() / 2, fn(i) { (v[2 * i], v[2 * i + 1]) })
}

///|
pub fn call_shape(
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
/// A generator configured like the fixture's `rough.generator(config)`.
pub fn fixture_generator(
  config : StringView,
) -> (@core.Generator, @random.RandomSource) raise {
  let source = @random.RandomSource::park_miller(FALLBACK_SEED)
  let generator = match decode_options(config) {
    Some(config) => @core.Generator::new(options=config, source~)
    None => @core.Generator::new(source~)
  }
  (generator, source)
}
