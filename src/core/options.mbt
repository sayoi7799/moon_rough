// rough.js 4.6.6 src/core.ts (Options, ResolvedOptions) and the defaults of
// src/generator.ts.

///|
/// `fillStyle`. rough.js treats unknown names as `hachure`.
pub(all) enum FillStyle {
  Hachure
  Solid
  Zigzag
  CrossHatch
  Dots
  Dashed
  ZigzagLine
} derive(Eq, Debug)

///|
/// The rough.js name: `"hachure"`, `"cross-hatch"`, `"zigzag-line"`, ...
pub fn FillStyle::name(self : FillStyle) -> String {
  match self {
    Hachure => "hachure"
    Solid => "solid"
    Zigzag => "zigzag"
    CrossHatch => "cross-hatch"
    Dots => "dots"
    Dashed => "dashed"
    ZigzagLine => "zigzag-line"
  }
}

///|
/// Parses a rough.js fill style name; like rough.js, anything unknown is
/// `Hachure`.
pub fn FillStyle::from_name(name : StringView) -> FillStyle {
  match name {
    "solid" => Solid
    "zigzag" => Zigzag
    "cross-hatch" => CrossHatch
    "dots" => Dots
    "dashed" => Dashed
    "zigzag-line" => ZigzagLine
    _ => Hachure
  }
}

///|
/// Drawing options; `None` fields take the generator's defaults. This is
/// rough.js' `Options`, with the same meaning for every field.
pub(all) struct Options {
  max_randomness_offset : Double?
  roughness : Double?
  bowing : Double?
  stroke : String?
  stroke_width : Double?
  curve_fitting : Double?
  curve_tightness : Double?
  curve_step_count : Double?
  fill : String?
  fill_style : FillStyle?
  fill_weight : Double?
  hachure_angle : Double?
  hachure_gap : Double?
  simplification : Double?
  dash_offset : Double?
  dash_gap : Double?
  zigzag_offset : Double?
  seed : Int32?
  stroke_line_dash : Array[Double]?
  stroke_line_dash_offset : Double?
  fill_line_dash : Array[Double]?
  fill_line_dash_offset : Double?
  disable_multi_stroke : Bool?
  disable_multi_stroke_fill : Bool?
  preserve_vertices : Bool?
  fixed_decimal_place_digits : Int32?
  fill_shape_roughness_gain : Double?
}

///|
/// Builds `Options` from labelled arguments, e.g.
/// `Options::new(roughness=2.0, fill="red", fill_style=CrossHatch, seed=7)`.
pub fn Options::new(
  max_randomness_offset? : Double,
  roughness? : Double,
  bowing? : Double,
  stroke? : String,
  stroke_width? : Double,
  curve_fitting? : Double,
  curve_tightness? : Double,
  curve_step_count? : Double,
  fill? : String,
  fill_style? : FillStyle,
  fill_weight? : Double,
  hachure_angle? : Double,
  hachure_gap? : Double,
  simplification? : Double,
  dash_offset? : Double,
  dash_gap? : Double,
  zigzag_offset? : Double,
  seed? : Int32,
  stroke_line_dash? : Array[Double],
  stroke_line_dash_offset? : Double,
  fill_line_dash? : Array[Double],
  fill_line_dash_offset? : Double,
  disable_multi_stroke? : Bool,
  disable_multi_stroke_fill? : Bool,
  preserve_vertices? : Bool,
  fixed_decimal_place_digits? : Int32,
  fill_shape_roughness_gain? : Double,
) -> Options {
  {
    max_randomness_offset,
    roughness,
    bowing,
    stroke,
    stroke_width,
    curve_fitting,
    curve_tightness,
    curve_step_count,
    fill,
    fill_style,
    fill_weight,
    hachure_angle,
    hachure_gap,
    simplification,
    dash_offset,
    dash_gap,
    zigzag_offset,
    seed,
    stroke_line_dash,
    stroke_line_dash_offset,
    fill_line_dash,
    fill_line_dash_offset,
    disable_multi_stroke,
    disable_multi_stroke_fill,
    preserve_vertices,
    fixed_decimal_place_digits,
    fill_shape_roughness_gain,
  }
}

///|
/// Options with every default applied: rough.js' `ResolvedOptions`.
///
/// Like the JavaScript object, it also carries the lazily created random
/// number generator. Copies made while drawing (`{ ...o, ... }` in rough.js)
/// share it if it already exists and create their own otherwise, and a
/// generator's default options keep theirs across calls; both behaviours are
/// reproduced because they decide which random numbers each shape gets.
pub struct ResolvedOptions {
  max_randomness_offset : Double
  roughness : Double
  bowing : Double
  stroke : String
  stroke_width : Double
  curve_fitting : Double
  curve_tightness : Double
  curve_step_count : Double
  fill : String?
  fill_style : FillStyle
  fill_weight : Double
  hachure_angle : Double
  hachure_gap : Double
  simplification : Double?
  dash_offset : Double
  dash_gap : Double
  zigzag_offset : Double
  seed : Int32
  stroke_line_dash : Array[Double]?
  stroke_line_dash_offset : Double?
  fill_line_dash : Array[Double]?
  fill_line_dash_offset : Double?
  disable_multi_stroke : Bool
  disable_multi_stroke_fill : Bool
  preserve_vertices : Bool
  fixed_decimal_place_digits : Int32?
  fill_shape_roughness_gain : Double
  priv mut randomizer : @random.Random?
  priv source : @random.RandomSource
}

///|
/// The defaults of `RoughGenerator`.
fn default_options(source : @random.RandomSource) -> ResolvedOptions {
  {
    max_randomness_offset: 2.0,
    roughness: 1.0,
    bowing: 1.0,
    stroke: "#000",
    stroke_width: 1.0,
    curve_tightness: 0.0,
    curve_fitting: 0.95,
    curve_step_count: 9.0,
    fill: None,
    fill_style: Hachure,
    fill_weight: -1.0,
    hachure_angle: -41.0,
    hachure_gap: -1.0,
    simplification: None,
    dash_offset: -1.0,
    dash_gap: -1.0,
    zigzag_offset: -1.0,
    seed: 0,
    stroke_line_dash: None,
    stroke_line_dash_offset: None,
    fill_line_dash: None,
    fill_line_dash_offset: None,
    disable_multi_stroke: false,
    disable_multi_stroke_fill: false,
    preserve_vertices: false,
    fixed_decimal_place_digits: None,
    fill_shape_roughness_gain: 0.8,
    randomizer: None,
    source,
  }
}

///|
/// `Object.assign({}, base, options)`: a new object; the randomizer (if any)
/// is shared with `base`.
fn ResolvedOptions::merge(
  base : ResolvedOptions,
  options : Options,
) -> ResolvedOptions {
  {
    max_randomness_offset: options.max_randomness_offset.unwrap_or(
      base.max_randomness_offset,
    ),
    roughness: options.roughness.unwrap_or(base.roughness),
    bowing: options.bowing.unwrap_or(base.bowing),
    stroke: options.stroke.unwrap_or(base.stroke),
    stroke_width: options.stroke_width.unwrap_or(base.stroke_width),
    curve_fitting: options.curve_fitting.unwrap_or(base.curve_fitting),
    curve_tightness: options.curve_tightness.unwrap_or(base.curve_tightness),
    curve_step_count: options.curve_step_count.unwrap_or(base.curve_step_count),
    fill: either(options.fill, base.fill),
    fill_style: options.fill_style.unwrap_or(base.fill_style),
    fill_weight: options.fill_weight.unwrap_or(base.fill_weight),
    hachure_angle: options.hachure_angle.unwrap_or(base.hachure_angle),
    hachure_gap: options.hachure_gap.unwrap_or(base.hachure_gap),
    simplification: either(options.simplification, base.simplification),
    dash_offset: options.dash_offset.unwrap_or(base.dash_offset),
    dash_gap: options.dash_gap.unwrap_or(base.dash_gap),
    zigzag_offset: options.zigzag_offset.unwrap_or(base.zigzag_offset),
    seed: options.seed.unwrap_or(base.seed),
    stroke_line_dash: either(options.stroke_line_dash, base.stroke_line_dash),
    stroke_line_dash_offset: either(
      options.stroke_line_dash_offset,
      base.stroke_line_dash_offset,
    ),
    fill_line_dash: either(options.fill_line_dash, base.fill_line_dash),
    fill_line_dash_offset: either(
      options.fill_line_dash_offset,
      base.fill_line_dash_offset,
    ),
    disable_multi_stroke: options.disable_multi_stroke.unwrap_or(
      base.disable_multi_stroke,
    ),
    disable_multi_stroke_fill: options.disable_multi_stroke_fill.unwrap_or(
      base.disable_multi_stroke_fill,
    ),
    preserve_vertices: options.preserve_vertices.unwrap_or(
      base.preserve_vertices,
    ),
    fixed_decimal_place_digits: either(
      options.fixed_decimal_place_digits,
      base.fixed_decimal_place_digits,
    ),
    fill_shape_roughness_gain: options.fill_shape_roughness_gain.unwrap_or(
      base.fill_shape_roughness_gain,
    ),
    randomizer: base.randomizer,
    source: base.source,
  }
}

///|
/// The source of the `Math.random()` replacements used while drawing with
/// these options.
pub fn ResolvedOptions::random_source(
  self : ResolvedOptions,
) -> @random.RandomSource {
  self.source
}

///|
/// JavaScript truthiness of a number option.
fn truthy(x : Double) -> Bool {
  x != 0.0 && !x.is_nan()
}

///|
/// JavaScript truthiness of `o.fill` (`undefined` and `""` are falsy).
fn has_fill(o : ResolvedOptions) -> Bool {
  match o.fill {
    Some(fill) => fill != ""
    None => false
  }
}

///|
/// `a` if it is set, otherwise `b`.
fn[T] either(a : T?, b : T?) -> T? {
  match a {
    Some(_) => a
    None => b
  }
}
