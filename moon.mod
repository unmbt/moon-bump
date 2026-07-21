// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "unmbt/moon-bump"

version = "0.0.1"

readme = "README.mbt.md"

repository = ""

license = "MIT"

keywords = [ ]

preferred_target = "native"

description = ""

import {
  "moonbitlang/async@0.20.2",
  "mizchi/semver@0.1.1",
  "xingwangzhe/style_print@0.1.7",
  "mizchi/tui@0.10.0",
}
