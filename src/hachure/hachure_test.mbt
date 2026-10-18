///|
/// Decodes `x y x y ...;x y ...` polygons, re-creating the shared point
/// objects described by the identity signature (`n` new, `oK` = point K).
fn decode_polygons(
  s : StringView,
  ids : StringView,
) -> Array[Array[@geometry.Point]] raise {
  let ids = ids.split(",").to_array()
  let all : Array[@geometry.Point] = []
  let polygons = []
  for part in s.split(";") {
    let v = @fixture.hex_list(part)
    let polygon = []
    for i in 0..<(v.length() / 2) {
      let id = ids[all.length()]
      let p = if id.has_prefix("o") {
        all[@string.parse_int(id[1:])]
      } else {
        @geometry.Point::new(v[2 * i], v[2 * i + 1])
      }
      all.push(p)
      polygon.push(p)
    }
    polygons.push(polygon)
  }
  polygons
}

///|
test "hachure_lines matches hachure-fill, including the rotated-back polygons" {
  let stats = @fixture.ErrorStats::new("hachure")
  for n, entry in hachure_fixtures {
    let f = @fixture.fields(entry)
    let polygons = decode_polygons(f[0], f[1])
    let gap = @fixture.hex_to_double(f[2])
    let angle = @fixture.hex_to_double(f[3])
    let hachure_step_offset = @fixture.hex_to_double(f[4])
    let lines = @hachure.hachure_lines(
      polygons,
      gap,
      angle,
      hachure_step_offset~,
    )
    let expected = @fixture.hex_list(f[5])
    assert_eq(
      lines.length() * 4,
      expected.length(),
      msg="case \{n}: line count",
    )
    for i, line in lines {
      let actual = [line.0.x, line.0.y, line.1.x, line.1.y]
      for j in 0..<4 {
        assert_true(
          stats.record(actual[j], expected[4 * i + j]),
          msg="case \{n}: line \{i}",
        )
      }
    }
    let after = f[6].split(";").map(@fixture.hex_list).to_array()
    for i, polygon in polygons {
      for j, p in polygon {
        assert_true(
          stats.record(p.x, after[i][2 * j]) &&
          stats.record(p.y, after[i][2 * j + 1]),
          msg="case \{n}: polygon \{i} point \{j} after rotation",
        )
      }
    }
  }
  println(stats.summary())
}

///|
test "empty polygons are skipped" {
  let lines = @hachure.hachure_lines(
    [
      [],
      [
        @geometry.Point::new(0.0, 0.0),
        @geometry.Point::new(10.0, 0.0),
        @geometry.Point::new(10.0, 10.0),
      ],
    ],
    4.0,
    0.0,
  )
  assert_eq(lines.length(), 3)
}
