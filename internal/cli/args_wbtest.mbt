///|
test "CLI maps reliability flags and positional release" {
  let parsed = parse_argv([
    "patch", "README.md", "--sign", "--no-push", "--update", "--all", "--no-git-check",
    "--yes", "--no-verify", "--ignore-scripts", "--recursive", "--quiet", "--no-print-commits",
    "--current-version", "1.2.3", "--cwd", "project", "--commit", "ship %s", "--no-tag",
  ])
  guard parsed is Ok(value) else { fail("expected parsed arguments") }
  let raw = value.raw
  assert_eq(raw.release, Some("patch"))
  assert_eq(raw.files, Some(["README.md"]))
  assert_eq(raw.commit, Some(Template("ship %s")))
  assert_eq(raw.tag, Some(Disabled))
  assert_eq(raw.push, Some(false))
  assert_eq(raw.print_commits, Some(false))
  assert_eq(raw.current_version, Some("1.2.3"))
  assert_eq(raw.cwd, Some("project"))
  assert_true(raw.sign == Some(true) && raw.ignore_scripts == Some(true))
  assert_eq(raw.recursive, Some(true))
  assert_true(raw.no_git_check == Some(true) && raw.no_verify == Some(true))
}

///|
test "CLI requires values for commit and tag" {
  assert_true(parse_argv(["patch", "--commit"]) is Err(_))
  assert_true(parse_argv(["patch", "--tag"]) is Err(_))
}
