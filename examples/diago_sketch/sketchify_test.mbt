///|
fn count(s : String, pattern : String) -> Int32 {
  let mut n = 0
  let mut from = 0
  while true {
    match s[from:].find(pattern) {
      Some(i) => {
        n += 1
        from = from + i + pattern.length()
      }
      None => break
    }
  }
  n
}

///|
/// A diago-like document with one shape group around `body`.
fn shape(body : String) -> String {
  "<svg><g class=\"b2JqZWN0\"><g class=\"shape\" >\{body}</g></g></svg>"
}

///|
const RECT : String =
  #|<rect x="10" y="20" width="100" height="50" stroke="#0D32B2" fill="#F7F8FE" class=" stroke-B1 fill-B6" style="stroke-width:2;" />

///|
test "a rectangle becomes a fill path and an outline path" {
  let out = @diago_sketch.sketchify(shape(RECT))
  assert_eq(count(out, "<rect"), 0)
  assert_eq(count(out, "<path"), 2)
  // The fill path keeps the fill color and the fill class, and no stroke.
  assert_true(
    out.contains("fill=\"#F7F8FE\" stroke=\"none\" class=\"fill-B6\" />"),
  )
  // The outline keeps the stroke color, class and width, and no fill.
  assert_true(
    out.contains(
      "fill=\"none\" stroke=\"#0D32B2\" class=\"stroke-B1\" style=\"stroke-width:2;\" />",
    ),
  )
}

///|
test "the output is exactly what moon_rough draws for the same parameters" {
  let out = @diago_sketch.sketchify(shape(RECT), seed=3, roughness=1.5)
  let g = @moon_rough.generator()
  let drawable = g.rectangle(
    10.0,
    20.0,
    100.0,
    50.0,
    options=@moon_rough.Options::new(
      seed=3,
      roughness=1.5,
      stroke_width=2.0,
      fill="x",
      fill_style=Solid,
      stroke="x",
      fixed_decimal_place_digits=2,
    ),
  )
  assert_eq(drawable.sets.length(), 2)
  let fill_d = @moon_rough.ops_to_path(drawable.sets[0], fixed_decimals=2)
  let outline_d = @moon_rough.ops_to_path(drawable.sets[1], fixed_decimals=2)
  assert_true(out.contains("<path d=\"\{fill_d}\" fill="))
  assert_true(out.contains("<path d=\"\{outline_d}\" fill=\"none\""))
}

///|
test "every geometry element is drawn by hand" {
  for
    body in [
      "<ellipse cx=\"50\" cy=\"40\" rx=\"30\" ry=\"20\" stroke=\"#000\" fill=\"#fff\" />",
      "<circle cx=\"50\" cy=\"40\" r=\"20\" stroke=\"#000\" fill=\"#fff\" />", "<polygon points=\"0,0 40,0 20,30\" stroke=\"#000\" fill=\"#fff\" />",
      "<path d=\"M 0 0 L 40 0 L 20 30 Z\" stroke=\"#000\" fill=\"#fff\" />", "<line x1=\"0\" y1=\"0\" x2=\"40\" y2=\"30\" stroke=\"#000\" />",
      "<rect x=\"0\" y=\"0\" width=\"40\" height=\"30\" rx=\"6\" stroke=\"#000\" fill=\"#fff\" />",
    ] {
    let out = @diago_sketch.sketchify(shape(body))
    assert_eq(
      count(out, "<path"),
      if body.has_prefix("<line") {
        1
      } else {
        2
      },
      msg=body,
    )
    for tag in ["<ellipse", "<circle", "<polygon", "<line", "<rect"] {
      assert_eq(count(out, tag), 0, msg=body)
    }
  }
}

///|
test "no fill gives only an outline, no stroke gives only a fill" {
  let outline_only = @diago_sketch.sketchify(
    shape(
      "<rect x=\"0\" y=\"0\" width=\"40\" height=\"30\" stroke=\"#000\" fill=\"none\" />",
    ),
  )
  assert_eq(count(outline_only, "<path"), 1)
  let fill_only = @diago_sketch.sketchify(
    shape(
      "<rect x=\"0\" y=\"0\" width=\"40\" height=\"30\" stroke=\"none\" fill=\"#fff\" />",
    ),
  )
  assert_eq(count(fill_only, "<path"), 1)
  assert_true(fill_only.contains("stroke=\"none\""))
  // Nothing to draw: left as it is.
  let nothing = shape(
    "<rect x=\"0\" y=\"0\" width=\"40\" height=\"30\" fill=\"none\" stroke=\"none\" />",
  )
  assert_eq(@diago_sketch.sketchify(nothing), nothing)
}

///|
test "a connection keeps its attributes and only its path changes" {
  let source =
    #|<svg><g class="Y29ubg=="><path d="M 10 10 C 10 50 10 70 10 100" stroke="#0D32B2" fill="none" class="connection stroke-B1" style="stroke-width:2;" marker-end="url(#mk-1)" mask="url(#m)" /></g></svg>
  let out = @diago_sketch.sketchify(source)
  assert_eq(count(out, "<path"), 1)
  assert_true(
    out.contains(
      "\" stroke=\"#0D32B2\" fill=\"none\" class=\"connection stroke-B1\" style=\"stroke-width:2;\" marker-end=\"url(#mk-1)\" mask=\"url(#m)\" />",
    ),
  )
  assert_true(!out.contains("d=\"M 10 10 C 10 50 10 70 10 100\""))
  // The ends stay where they are so the arrowheads still touch the shapes.
  assert_true(out.contains("d=\"M10 10 "))
  assert_true(out.contains(" 10 100\""))
}

///|
test "an arrowhead is drawn by hand and its marker may overflow" {
  let source =
    #|<svg><g class="Y29ubg=="><marker id="mk-1" markerWidth="10" markerHeight="12" refX="7" refY="6" viewBox="0 0 10 12" orient="auto" markerUnits="userSpaceOnUse"> <polygon points="0,0 10,6 0,12" fill="#0D32B2" class="connection fill-B1" stroke-width="2" /> </marker></g></svg>
  let out = @diago_sketch.sketchify(source)
  assert_eq(count(out, "<polygon"), 0)
  assert_true(
    out.contains(
      "orient=\"auto\" markerUnits=\"userSpaceOnUse\" overflow=\"visible\">",
    ),
  )
  // The fill follows fill-B1, and the outline gets the matching stroke class
  // and the fill color as its stroke.
  assert_true(
    out.contains(
      "fill=\"#0D32B2\" stroke=\"none\" class=\"connection fill-B1\"",
    ),
  )
  assert_true(
    out.contains(
      "fill=\"none\" stroke=\"#0D32B2\" class=\"connection stroke-B1\"",
    ),
  )
}

///|
test "paint set on a group is inherited, not copied onto the paths" {
  let source =
    #|<svg><g class="Y29ubg=="><marker id="mk-1" viewBox="0 0 10 10" orient="auto"> <g stroke="#0D32B2" fill="#FFFFFF" class="connection stroke-B1 fill-N7" stroke-width="2"><circle r="3" cx="5" cy="5" /><path d="M0,5 9,5 M5,5 9,0" /></g> </marker></g></svg>
  let out = @diago_sketch.sketchify(source)
  assert_eq(count(out, "<circle"), 0)
  // The group stays as it is, so its classes keep controlling the colors.
  assert_true(
    out.contains(
      "<g stroke=\"#0D32B2\" fill=\"#FFFFFF\" class=\"connection stroke-B1 fill-N7\" stroke-width=\"2\">",
    ),
  )
  // The circle gets a fill path and an outline, none of which repeats a color.
  assert_true(out.contains("<path d=\""))
  assert_true(!out.contains("stroke=\"#0D32B2\" />"))
  // Lines have no area to fill, so they give a single outline and no empty path.
  assert_true(!out.contains("d=\"\""))
}

///|
test "text, styles, masks and anything outside a shape are copied through" {
  let source = "<?xml version=\"1.0\"?><!-- keep <this> --><svg><style>.a > .b { fill: red }</style><rect x=\"0\" y=\"0\" width=\"5\" height=\"5\" fill=\"#fff\" /><mask id=\"m\"><rect width=\"9\" height=\"9\" fill=\"black\"></rect></mask><g class=\"b2o=\"><text x=\"1\" y=\"2\">a &lt; b</text></g></svg>"
  assert_eq(@diago_sketch.sketchify(source), source)
}

///|
test "the n-th element uses seed + n, so equal elements look different" {
  let two = shape(RECT + RECT)
  let out = @diago_sketch.sketchify(two)
  let paths = out.split("<path").to_array()
  // paths[0] is the text before the first path.
  assert_eq(paths.length() - 1, 4)
  assert_true(paths[1] != paths[3])
}

///|
test "same input and arguments give the same output, other seeds do not" {
  let a = @diago_sketch.sketchify(shape(RECT), seed=5)
  let b = @diago_sketch.sketchify(shape(RECT), seed=5)
  let c = @diago_sketch.sketchify(shape(RECT), seed=6)
  assert_eq(a, b)
  assert_true(a != c)
}

///|
/// The two path strings are exactly what rough.js 4.6.6 gives for
/// `rough.generator().rectangle(10, 20, 100, 50, { seed: 1, roughness: 1,
/// strokeWidth: 2, fill: "x", fillStyle: "solid", stroke: "x" })` with
/// `opsToPath(set, 2)`; the rest is the markup around them.
test "output snapshot, identical on every backend" {
  inspect(
    @diago_sketch.sketchify(shape(RECT), seed=1),
    content=(
      #|<svg><g class="b2JqZWN0"><g class="shape" ><path d="M8.4 19.42 L111.05 21.81 L110.25 68.23 L10.93 71.53" fill="#F7F8FE" stroke="none" class="fill-B6" /><path d="M10.86 20.96 C29.68 20.96, 49.44 18.07, 109.21 20.39 M9.35 20.26 C32.57 20.38, 54.36 19.81, 109.42 20.75 M111.54 18.25 C110.87 32.11, 111.56 40.11, 111.39 69.13 M110.3 19.2 C110.4 32.56, 109.42 46.87, 110.41 70.35 M111.05 69.79 C89.46 70.8, 65.18 70.25, 11.84 69.6 M109.06 69.86 C72.32 70.38, 35.61 70.11, 10.94 70.04 M9.28 69.72 C10.9 54.13, 9.17 41.5, 10.59 18.79 M10.22 71 C8.92 51.16, 9.42 32.72, 10.44 20.99" fill="none" stroke="#0D32B2" class="stroke-B1" style="stroke-width:2;" /></g></g></svg>
    ),
  )
}

///|
test "malformed input is reported, not guessed at" {
  for
    bad in [
      "<svg><g class=\"shape\" ><rect x=\"1\"", "<svg><rect x=\"1 /></svg>", "<svg><!-- never closed",
      "<svg><style>.a{}",
    ] {
    try @diago_sketch.sketchify(bad) catch {
      @diago_sketch.Malformed(_) => ()
    } noraise {
      _ => fail("expected an error for \{bad}")
    }
  }
}

///|
test "empty input and plain text pass through" {
  assert_eq(@diago_sketch.sketchify(""), "")
  assert_eq(@diago_sketch.sketchify("no tags here"), "no tags here")
}

///|
test "diago's real output is redrawn completely" {
  let plain = @diago.compile("a: A\nb: B {shape: circle}\na -> b: go") catch {
    _ => fail("diago could not compile the diagram")
  }
  let out = @diago_sketch.sketchify(plain)
  // Inside shapes there are no geometry elements left; the background and
  // the label mask keep their rectangles.
  assert_eq(count(plain, "<ellipse"), 1)
  assert_eq(count(out, "<ellipse"), 0)
  assert_eq(count(out, "<polygon"), 0)
  assert_eq(count(plain, "<rect"), count(out, "<rect") + 1)
  assert_true(out.contains("marker-end=\"url(#mk-"))
  assert_true(out.contains("overflow=\"visible\""))
  assert_true(out.contains(">go</text>"))
  // And it is reproducible.
  assert_eq(out, @diago_sketch.sketchify(plain))
}
