///|
fn decode_segments(s : StringView) -> Array[@path_data.Segment] {
  if s.length() == 0 {
    return []
  }
  s
  .split(";")
  .map(fn(part) {
    let key = part.get_char(0).unwrap()
    let data = if part.length() > 1 { @fixture.hex_list(part[2:]) } else { [] }
    @path_data.Segment::{ key, data, }
  })
  .to_array()
}

///|
fn error_tag(e : @path_data.PathError) -> String {
  match e {
    InvalidCharacter(_) => "token"
    ParamNotANumber(mode, text) => "param:\{mode},\{text}"
    EndedShort => "short"
    NumberAfterClose => "after-close"
  }
}

///|
fn check_segments(
  stats : @fixture.ErrorStats,
  what : String,
  d : StringView,
  actual : Array[@path_data.Segment],
  expected : Array[@path_data.Segment],
) -> Unit raise {
  assert_eq(
    actual.length(),
    expected.length(),
    msg="\{what} of \{d}: segment count",
  )
  for i, e in expected {
    let a = actual[i]
    assert_eq(a.key, e.key, msg="\{what} of \{d}: key of segment \{i}")
    assert_eq(
      a.data.length(),
      e.data.length(),
      msg="\{what} of \{d}: segment \{i}",
    )
    for j, v in e.data {
      assert_true(
        stats.record(a.data[j], v),
        msg="\{what} of \{d}: segment \{i}, value \{j}: \{a.data[j]} vs \{v}",
      )
    }
  }
}

///|
test "parse, absolutize, normalize and serialize match path-data-parser" {
  let stats = @fixture.ErrorStats::new("path_data")
  let mut ok = 0
  let mut errors = 0
  for entry in path_fixtures {
    let f = @fixture.fields(entry)
    let d = f[0]
    if f[1] != "ok" {
      let tag = try @path_data.parse_path(d) catch {
        e => error_tag(e)
      } noraise {
        _ => "ok"
      }
      assert_eq(tag, f[1].to_owned(), msg="error for \{d}")
      errors += 1
      continue
    }
    let parsed = @path_data.parse_path(d)
    check_segments(stats, "parse", d, parsed, decode_segments(f[2]))
    let abs = @path_data.absolutize(parsed)
    check_segments(stats, "absolutize", d, abs, decode_segments(f[3]))
    let norm = @path_data.normalize(abs)
    check_segments(stats, "normalize", d, norm, decode_segments(f[4]))
    assert_eq(
      @path_data.serialize(parsed),
      f[5].to_owned(),
      msg="serialize \{d}",
    )
    ok += 1
  }
  assert_true(ok > 300 && errors > 10)
  println(stats.summary())
}

///|
test "numbers after Z are an error instead of rough.js' endless loop" {
  for d in ["M 1 1 Z 5", "M 1 1 z 5 5", "M 0 0 L 1 1 Z,2"] {
    try @path_data.parse_path(d) catch {
      e => assert_eq(e, @path_data.NumberAfterClose, msg=d)
    } noraise {
      _ => fail("expected \{d} to raise")
    }
  }
}

///|
test "invalid characters report their offset" {
  try @path_data.parse_path("M 10 10 L 20 # 30") catch {
    e => assert_eq(e, @path_data.InvalidCharacter(13))
  } noraise {
    _ => fail("expected an error")
  }
}
