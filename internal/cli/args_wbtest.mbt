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

///|
test "CLI maps work releases to workspace mode" {
  guard parse_argv(["work", "minor", "--yes"]) is Ok(parsed) else {
    fail("expected workspace arguments")
  }
  assert_eq(parsed.raw.release, Some("minor"))
  assert_eq(parsed.raw.workspace, Some(true))
  assert_true(!parsed.workspace_init)
}

///|
test "CLI opens the workspace release prompt without a release argument" {
  guard parse_argv(["work"]) is Ok(parsed) else {
    fail("expected workspace prompt arguments")
  }
  assert_eq(parsed.raw.release, None)
  assert_eq(parsed.raw.workspace, Some(true))
}

///|
test "CLI maps workspace member selection" {
  guard parse_argv(["work", "patch", "packages/a", "--select"]) is Ok(parsed) else {
    fail("expected workspace selection arguments")
  }
  assert_eq(parsed.raw.files, Some(["packages/a"]))
  assert_eq(parsed.raw.workspace_select, Some(true))
}

///|
test "CLI preserves work init paths for Moon delegation" {
  guard parse_argv(["work", "init", "packages/a", "packages/b"]) is Ok(parsed) else {
    fail("expected workspace init arguments")
  }
  assert_true(parsed.workspace_init)
  assert_eq(parsed.workspace_paths, ["packages/a", "packages/b"])
}
