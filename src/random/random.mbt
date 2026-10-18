// Port of rough.js 4.6.6 src/math.ts (Random, randomSeed).

///|
/// Where the random numbers that rough.js takes from `Math.random()` come
/// from. rough.js uses `Math.random()` when the seed is 0, for the dot
/// positions of the `dots` fill style and as a fallback in the hachure filler,
/// so those outputs are not reproducible in rough.js itself; here the source
/// can be injected to make them deterministic.
///
/// A source is shared by all `Random`s created from the same generator and
/// counts the numbers drawn, which the tests compare with rough.js.
pub struct RandomSource {
  priv fallback : () -> Double
  priv mut seeded_calls : Int
  priv mut fallback_calls : Int
}

///|
/// A source whose `Math.random()` replacement is `fallback`, which must return
/// numbers in `[0, 1)`.
pub fn RandomSource::new(fallback : () -> Double) -> RandomSource {
  { fallback, seeded_calls: 0, fallback_calls: 0, }
}

///|
/// A source whose `Math.random()` replacement is the same Park-Miller
/// sequence rough.js' `Random` produces for `seed` (which must not be 0).
pub fn RandomSource::park_miller(seed : Int) -> RandomSource {
  let mut state = seed
  RandomSource::new(fn() {
    state = 48271 * state
    (state & 0x7fffffff).to_double() / 2147483648.0
  })
}

///|
/// The default source: `Math.random()` is replaced by `@core_random.Rand`.
pub fn RandomSource::default() -> RandomSource {
  let rand = @core_random.Rand::new()
  RandomSource::new(fn() { rand.double() })
}

///|
/// The equivalent of calling `Math.random()`.
pub fn RandomSource::fallback(self : RandomSource) -> Double {
  self.fallback_calls += 1
  (self.fallback)()
}

///|
/// How many seeded numbers (`Random::next` with a non-zero seed) were drawn.
pub fn RandomSource::seeded_calls(self : RandomSource) -> Int {
  self.seeded_calls
}

///|
/// How many `Math.random()` replacements were drawn.
pub fn RandomSource::fallback_calls(self : RandomSource) -> Int {
  self.fallback_calls
}

///|
/// rough.js' `Random`: a Park-Miller (MINSTD, multiplier 48271) generator.
pub struct Random {
  priv mut seed : Int
  priv source : RandomSource
}

///|
/// `new Random(seed)`. With seed 0, `next` delegates to `source.fallback()`.
pub fn Random::new(seed : Int, source? : RandomSource) -> Random {
  let source = match source {
    Some(source) => source
    None => RandomSource::default()
  }
  { seed, source, }
}

///|
/// The next number in `[0, 1)`.
///
/// rough.js: `((2 ** 31 - 1) & (this.seed = Math.imul(48271, this.seed))) / 2 ** 31`.
/// MoonBit's `Int` multiplication wraps around at 32 bits exactly like
/// `Math.imul`.
pub fn Random::next(self : Random) -> Double {
  if self.seed != 0 {
    self.source.seeded_calls += 1
    self.seed = 48271 * self.seed
    (self.seed & 0x7fffffff).to_double() / 2147483648.0
  } else {
    self.source.fallback()
  }
}

///|
/// `randomSeed()` / `rough.newSeed()`: `Math.floor(Math.random() * 2 ** 31)`.
pub fn new_seed(source : RandomSource) -> Int {
  (source.fallback() * 2147483648.0).floor().to_int()
}
