///|
test "first 1000 outputs match rough.js Random for every seed" {
  let stats = @fixture.ErrorStats::new("random")
  for entry in random_fixtures {
    let parts = @fixture.fields(entry)
    let seed = @string.parse_int(parts[0])
    let expected = @fixture.hex_list(parts[1])
    let source = @random.RandomSource::park_miller(1)
    let r = @random.Random::new(seed, source~)
    for i, e in expected {
      let v = r.next()
      ignore(stats.record(v, e))
      assert_true(v == e, msg="seed \{seed}, output \{i}: \{v} != \{e}")
    }
    assert_eq(source.seeded_calls(), 1000)
    assert_eq(source.fallback_calls(), 0)
  }
  assert_eq(stats.inexact, 0)
  println(stats.summary())
}

///|
test "seed 0 draws from the injected Math.random replacement" {
  let parts = @fixture.fields(fallback_fixtures[0])
  let source = @random.RandomSource::park_miller(@string.parse_int(parts[0]))
  let r = @random.Random::new(0, source~)
  for e in @fixture.hex_list(parts[1]) {
    assert_eq(r.next(), e)
  }
  assert_eq(source.seeded_calls(), 0)
  assert_eq(source.fallback_calls(), 100)
}

///|
test "new_seed is in [0, 2^31)" {
  let source = @random.RandomSource::new(fn() { 0.9999999995343387 })
  assert_eq(@random.new_seed(source), 2147483647)
  assert_eq(@random.new_seed(@random.RandomSource::new(fn() { 0.0 })), 0)
}
