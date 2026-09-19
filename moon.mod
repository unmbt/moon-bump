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

version = "0.1.4"

readme = "README.md"

repository = "https://github.com/unmbt/moon-bump"

license = "MIT"

keywords = [ "cli", "versioning", "release", "semver", "moonbit" ]

preferred_target = "native"

description = "An elegant, interactive version bumping and release tool for MoonBit packages."

import {
  "moonbitlang/async@0.22.1",
  "moonbitlang/x@0.5.5",
  "mizchi/semver@0.1.2",
  "mizchi/syntree@0.2.4",
  "mizchi/tui@0.10.2",
}

options(
  scripts: {
    "preversion": "echo 'preversion script!'",
    "version": "echo 'version script!'",
    "postversion": "echo 'postversion script!'",
  },
)
