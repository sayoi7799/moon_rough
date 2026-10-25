///|
/// Prints the same diagram hand-drawn: diago's SVG, redrawn by moon_rough.
fn main {
  let svg = @diago.compile(@demo_diagram.source) catch {
    _ => abort("diago could not compile the diagram")
  }
  let sketch = @diago_sketch.sketchify(svg, seed=7) catch {
    _ => abort("the SVG could not be redrawn")
  }
  println(sketch)
}
