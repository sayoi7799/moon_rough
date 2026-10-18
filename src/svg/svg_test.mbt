///|
fn decode_ops(s : StringView) -> Array[@core.Op] {
  // "P:m hex hex,c hex hex hex hex hex hex,..."
  s[2:]
  .split(",")
  .map(fn(op) {
    let v = @fixture.hex_list(op[2:])
    match op[0:1] {
      "m" => @core.Move(v[0], v[1])
      "l" => @core.LineTo(v[0], v[1])
      _ => @core.BCurveTo(v[0], v[1], v[2], v[3], v[4], v[5])
    }
  })
  .to_array()
}

///|
test "ops_to_path formats numbers like rough.js' opsToPath" {
  for entry in ops_to_path_fixtures {
    let f = @fixture.fields(entry)
    let drawing : @core.OpSet = { kind: Path, ops: decode_ops(f[0]), }
    let d = if f[1] == "-" {
      @core.ops_to_path(drawing)
    } else {
      @core.ops_to_path(drawing, fixed_decimals=@string.parse_int(f[1]))
    }
    assert_eq(d, f[2].to_owned())
  }
}

///|
test "drawable_to_svg writes one path per op set with RoughSVG's attributes" {
  let g = @core.Generator::new()
  let d = g.polygon(
    [(10.0, 10.0), (90.0, 20.0), (40.0, 80.0)],
    options=@core.Options::new(
      seed=7,
      fill="#f00",
      fill_style=Solid,
      stroke="#123",
      stroke_width=2.5,
      stroke_line_dash=[4.0, 2.0],
      fixed_decimal_place_digits=2,
    ),
  )
  let svg = @svg.drawable_to_svg(d)
  assert_true(svg.has_prefix("<g><path d=\"M"))
  assert_true(svg.has_suffix("/></g>"))
  let paths = svg.split("<path").to_array()
  assert_eq(paths.length() - 1, d.sets.length())
  // fillPath first: no stroke, evenodd for polygons.
  assert_true(
    paths[1].contains(
      "\" stroke=\"none\" stroke-width=\"0\" fill=\"#f00\" fill-rule=\"evenodd\"/>",
    ),
  )
  // then the outline.
  assert_true(
    paths[2].contains(
      "\" stroke=\"#123\" stroke-width=\"2.5\" fill=\"none\" stroke-dasharray=\"4 2\"/>",
    ),
  )
  // fixed_decimal_place_digits=2: no number has more than two decimals.
  let mut decimals = -1
  for c in svg {
    if c == '.' {
      decimals = 0
    } else if decimals >= 0 && c >= '0' && c <= '9' {
      decimals += 1
      assert_true(decimals <= 2, msg=svg)
    } else {
      decimals = -1
    }
  }
}

///|
test "fill sketches are stroked with the fill color and fill weight" {
  let g = @core.Generator::new()
  let d = g.rectangle(
    0.0,
    0.0,
    50.0,
    30.0,
    options=@core.Options::new(seed=3, fill="blue", stroke_width=3.0),
  )
  let svg = @svg.drawable_to_svg(d)
  assert_true(
    svg.contains("\" stroke=\"blue\" stroke-width=\"1.5\" fill=\"none\"/>"),
  )
}

///|
test "attribute values are escaped" {
  assert_eq(@svg.escape_attribute("a&b<\"c\">"), "a&amp;b&lt;&quot;c&quot;&gt;")
}

///|
test "svg_document wraps content" {
  assert_eq(
    @svg.svg_document(10.0, 20.5, "<g></g>", background="#fff"),
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"20.5\" viewBox=\"0 0 10 20.5\"><rect width=\"100%\" height=\"100%\" fill=\"#fff\"/><g></g></svg>",
  )
}
