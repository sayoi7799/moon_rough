name = "sayoi7799/diago_sketch"

version = "0.1.0"

license = "MIT"

description = "Turns diago SVG diagrams into hand-drawn ones with moon_rough."

import {
  "moonbit-community/diago@0.4.0",
  "sayoi7799/moon_rough@0.1.0",
}

// Derived trait methods (Eq, Debug) are promoted to methods on purpose.

warnings = "-implicit_impl_as_method"
