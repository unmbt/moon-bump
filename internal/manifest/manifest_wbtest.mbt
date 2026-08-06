///|
test "manifest version editing ignores comments and preserves quote style" {
  let content = "# version = \"9.9.9\"\nname = \"demo\"\nversion = '1.2.3'\noptions(version: \"ignored\")\n"
  assert_eq(read_version(content), Ok("1.2.3"))
  guard update_version(content, "2.0.0") is Ok(updated) else {
    fail("expected edit")
  }
  assert_true(updated.find("# version = \"9.9.9\"") is Some(_))
  assert_true(updated.find("version = '2.0.0'") is Some(_))
  assert_true(updated.find("options(version: \"ignored\")") is Some(_))
}

///|
test "manifest accepts whitespace and double-quoted versions" {
  assert_eq(
    read_version("name = \"demo\"\nversion\t =  \"1.2.3\"\n"),
    Ok("1.2.3"),
  )
}

///|
test "manifest version must be present and unique" {
  assert_true(read_version("name = \"demo\"\n") is Err(_))
  assert_true(
    read_version("version = \"1.0.0\"\nversion = \"2.0.0\"\n") is Err(_),
  )
}

///|
test "lifecycle scripts handle escaped and literal strings" {
  let content = "version = \"1.0.0\"\noptions(scripts: {\"preversion\": \"echo \\\"pre\\\"\", 'version': 'moon test', \"postversion\": \"echo done\"})\n"
  guard read_scripts(content) is Ok(scripts) else { fail("expected scripts") }
  assert_eq(scripts.preversion, Some("echo \"pre\""))
  assert_eq(scripts.version, Some("moon test"))
  assert_eq(scripts.postversion, Some("echo done"))
}

///|
test "text updates only replace version-number boundaries" {
  let content = "v1.2.3 11.2.3 1.2.30 1.2.3"
  assert_eq(
    update_text_version(content, "1.2.3", "2.0.0"),
    "v2.0.0 11.2.3 1.2.30 2.0.0",
  )
}

///|
async test "recursive discovery includes untracked manifests and excludes generated trees" {
  let root = "_build/moon-bump-tests/manifest-discovery"
  if @fs.exists(root) {
    @fs.rmdir(root, recursive=true)
  }
  @fs.mkdir(root + "/packages/a", recursive=true)
  @fs.mkdir(root + "/.git/hidden", recursive=true)
  @fs.mkdir(root + "/_build/hidden", recursive=true)
  @fs.mkdir(root + "/.mooncakes/hidden", recursive=true)
  @fs.mkdir(root + "/fixtures/hidden", recursive=true)
  @fs.write_file(
    root + "/moon.mod",
    "version = \"1.0.0\"",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/packages/a/moon.mod",
    "version = \"1.0.0\"",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/.git/hidden/moon.mod",
    "version = \"1.0.0\"",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/_build/hidden/moon.mod",
    "version = \"1.0.0\"",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/.mooncakes/hidden/moon.mod",
    "version = \"1.0.0\"",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    root + "/fixtures/hidden/moon.mod",
    "version = \"1.0.0\"",
    create_mode=CreateOrTruncate,
  )
  let options = {
    ..@model.Options::default(),
    cwd: root,
    recursive: true,
    files_explicit: false,
  }
  let result = discover_files(options)
  @fs.rmdir(root, recursive=true)
  assert_eq(result, Ok(["moon.mod", "packages/a/moon.mod"]))
}
