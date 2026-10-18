// moon_rough: a MoonBit port of rough.js 4.6.6.
//
// This package re-exports the public API of the sub-packages so that most
// programs only need `sayoi7799/moon_rough`:
//
//   let gen = @moon_rough.generator()
//   let d = gen.rectangle(10, 10, 200, 100, options=@moon_rough.Options::new(seed=1, fill="red"))
//   println(@moon_rough.drawable_to_svg(d))

///|
pub using @core {
  type Generator,
  type Options,
  type ResolvedOptions,
  type Drawable,
  type OpSet,
  type OpSetType,
  type Op,
  type FillStyle,
  type Shape,
  type PathInfo,
  ops_to_path,
}

///|
pub using @svg {drawable_to_svg, svg_document}

///|
pub using @random {type RandomSource}

///|
pub using @path_data {type PathError}

///|
/// `rough.generator({ options })`: a generator whose shapes use `options`
/// as defaults. `source` replaces JavaScript's `Math.random()` (used for seed
/// 0 and the `dots` fill); pass `RandomSource::park_miller(n)` for fully
/// reproducible output.
pub fn generator(options? : Options, source? : RandomSource) -> Generator {
  match (options, source) {
    (Some(options), Some(source)) => Generator::new(options~, source~)
    (Some(options), None) => Generator::new(options~)
    (None, Some(source)) => Generator::new(source~)
    (None, None) => Generator::new()
  }
}
