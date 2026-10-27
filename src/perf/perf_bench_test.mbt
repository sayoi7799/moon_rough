// Benchmarks, run with
//
//   moon bench --release --target <js | wasm-gc | native> -p sayoi7799/moon_rough/perf
//
// scripts/bench_roughjs.mjs times the same work with rough.js on Node, and
// scripts/bench.mjs runs everything and prints the table of the README. The
// names here are the keys the two sides are matched by. Only generating is
// timed, not drawing; the inputs are made before the timer starts.

///|
test "random_shapes_10k" (it : @bench.T) {
  let g = @core.Generator::new()
  let cases = @perf.random_cases(@perf.SHAPES, @perf.SHAPE_SEED)
  it.bench(fn() {
    for c in cases {
      it.keep(c.generate(g))
    }
  })
}

///|
test "dots_500" (it : @bench.T) {
  let g = @core.Generator::new()
  let cases = @perf.random_cases(@perf.DOTS, @perf.DOTS_SEED, dots=true)
  it.bench(fn() {
    for c in cases {
      it.keep(c.generate(g))
    }
  })
}

///|
test "path_parse" (it : @bench.T) {
  let d = @perf.complex_path(@perf.SEGMENTS, @perf.PATH_SEED)
  it.bench(fn() {
    let segments = @path_data.parse_path(d) catch { _ => abort("bad path") }
    it.keep(@path_data.normalize(@path_data.absolutize(segments)))
  })
}

///|
test "path_points_on_path" (it : @bench.T) {
  let d = @perf.complex_path(@perf.SEGMENTS, @perf.PATH_SEED)
  it.bench(fn() {
    it.keep(
      @curve.points_on_path(d, tolerance=1.0, distance=1.0) catch {
        _ => abort("bad path")
      },
    )
  })
}

///|
fn bench_path_fill(it : @bench.T, style : @core.FillStyle) -> Unit {
  let d = @perf.complex_path(@perf.SEGMENTS, @perf.PATH_SEED)
  let g = @core.Generator::new()
  let options = @core.Options::new(
    seed=1,
    fill="#e76f51",
    fill_style=style,
    hachure_gap=8.0,
  )
  it.bench(fn() {
    it.keep(g.path(d, options~) catch { _ => abort("bad path") })
  })
}

///|
test "path_fill_hachure" (it : @bench.T) {
  bench_path_fill(it, Hachure)
}

///|
test "path_fill_solid" (it : @bench.T) {
  bench_path_fill(it, Solid)
}

///|
test "path_fill_cross_hatch" (it : @bench.T) {
  bench_path_fill(it, CrossHatch)
}

///|
fn bench_svg(it : @bench.T, fixed_digits : Int32?) -> Unit {
  let g = @core.Generator::new()
  let cases = match fixed_digits {
    Some(digits) =>
      @perf.random_cases(@perf.SHAPES, @perf.SHAPE_SEED, fixed_digits=digits)
    None => @perf.random_cases(@perf.SHAPES, @perf.SHAPE_SEED)
  }
  // The drawables are made before the timer starts.
  let drawables = cases.map(fn(c) { c.generate(g) })
  it.bench(fn() {
    for drawable in drawables {
      it.keep(@svg.drawable_to_svg(drawable))
    }
  })
}

///|
test "svg_output_10k" (it : @bench.T) {
  bench_svg(it, None)
}

///|
test "svg_output_10k_fixed2" (it : @bench.T) {
  bench_svg(it, Some(2))
}
