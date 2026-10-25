///|
/// Prints the diagram as diago draws it.
fn main {
  let svg = @diago.compile(@demo_diagram.source) catch {
    _ => abort("diago could not compile the diagram")
  }
  println(svg)
}
