///|
test "configuration JSON maps all supported fields" {
  let content =
    #|{
    #|  "release": "minor",
    #|  "preid": "rc",
    #|  "commit": "ship %s",
    #|  "tag": false,
    #|  "sign": true,
    #|  "push": false,
    #|  "update": true,
    #|  "all": true,
    #|  "noGitCheck": true,
    #|  "confirm": false,
    #|  "noVerify": true,
    #|  "files": ["moon.mod", "README.md"],
    #|  "cwd": "project",
    #|  "ignoreScripts": true,
    #|  "recursive": true,
    #|  "printCommits": false,
    #|  "quiet": true,
    #|  "currentVersion": "1.2.3",
    #|  "execute": "moon test"
    #|}
  let parsed = parse_config(content, "config.json")
  guard parsed is Ok(raw) else { fail("expected valid config") }
  guard normalize(raw) is Ok(options) else {
    fail("expected normalized config")
  }
  assert_eq(options.release, Bump(Minor))
  assert_eq(options.preid, "rc")
  assert_eq(options.commit.map(fn(value) { value.message }), Some("ship %s"))
  assert_eq(options.tag, None)
  assert_true(options.sign && !options.push && options.update && options.all)
  assert_true(
    options.no_git_check && !options.confirm && options.ignore_scripts,
  )
  assert_true(options.files_explicit && !options.recursive)
  assert_eq(options.current_version, Some("1.2.3"))
}

///|
test "configuration rejects invalid field types" {
  assert_true(parse_config("{\"push\": \"yes\"}", "config.json") is Err(_))
  assert_true(parse_config("{\"files\": [1]}", "config.json") is Err(_))
}

///|
test "CLI values override configured values and file lists" {
  let configured = {
    ..@model.RawOptions::empty(),
    push: Some(false),
    files: Some(["a"]),
  }
  let cli = {
    ..@model.RawOptions::empty(),
    push: Some(true),
    files: Some(["b"]),
  }
  guard normalize(configured.merge(cli)) is Ok(options) else {
    fail("expected options")
  }
  assert_true(options.push)
  assert_eq(options.files, ["b"])
}

///|
async test "explicit missing configuration is an error" {
  let result = load(
    @model.RawOptions::empty(),
    Some("_build/moon-bump-tests/missing-config.json"),
  )
  assert_true(result is Err(_))
}
