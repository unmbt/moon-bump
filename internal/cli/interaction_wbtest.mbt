///|
test "release selection cursor wraps in both directions" {
  assert_eq(previous_cursor(0, 4), 3)
  assert_eq(previous_cursor(2, 4), 1)
  assert_eq(next_cursor(3, 4), 0)
  assert_eq(next_cursor(1, 4), 2)
}

///|
test "commit types keep their semantic colors" {
  assert_eq(commit_type_style("feat"), (@render.ansi_fg_green(), true))
  assert_eq(commit_type_style("fix"), (@render.ansi_fg_yellow(), true))
  assert_eq(commit_type_style("refactor"), (@render.ansi_fg_cyan(), true))
  assert_eq(commit_type_style("chore"), (@render.ansi_fg_gray(), false))
}

///|
test "commit type columns align before the scope and colon" {
  let feat = padded_commit_type("feat", 8)
  let refactor = padded_commit_type("refactor", 8)
  assert_eq(feat, "     feat")
  assert_eq(refactor, " refactor")
  assert_eq(feat.length(), refactor.length())
}

///|
test "backspace removes one Unicode character" {
  assert_eq(remove_last_char("release \u{1F600}"), "release ")
  assert_eq(remove_last_char(""), "")
}

///|
test "workspace release choices can hide candidate versions" {
  let context : @model.ReleaseContext = {
    options: @model.Options::default(),
    files: ["moon.mod"],
    current_version: "1.0.0",
    commits: [],
    scripts: @model.LifecycleScripts::empty(),
  }
  let hidden = release_choices(context, false)
  assert_eq(hidden[0].1, "patch")
  assert_eq(hidden[0].2, "")
  assert_eq(hidden[9].1, "as-is")
  assert_eq(hidden[9].2, "")
  let visible = release_choices(context, true)
  assert_eq(visible[0].2, "1.0.1")
  assert_eq(visible[9].2, "1.0.0")
}

///|
test "workspace bump selection replaces and removes a package" {
  let first : @model.WorkspaceBump = {
    path: "packages/a/moon.mod",
    current_version: "1.0.0",
    release: Bump(Patch),
    new_version: "1.0.1",
  }
  let replacement : @model.WorkspaceBump = {
    ..first,
    release: Bump(Minor),
    new_version: "1.1.0",
  }
  let bumps = upsert_workspace_bump([], first)
  let replaced = upsert_workspace_bump(bumps, replacement)
  assert_eq(replaced.length(), 1)
  assert_eq(replaced[0].new_version, "1.1.0")
  assert_eq(remove_workspace_bump(replaced, first.path), [])
}

///|
test "no-op plans skip confirmation" {
  let plan : @model.ReleasePlan = {
    options: { ..@model.Options::default(), quiet: true, confirm: true, },
    current_version: "1.0.0",
    new_version: "1.0.0",
    edits: [],
    skipped_files: [],
    commit_message: Some("release: v1.0.0"),
    tag_name: Some("v1.0.0"),
    scripts: {
      preversion: Some("exit 9"),
      version: Some("exit 9"),
      postversion: Some("exit 9"),
    },
  }
  assert_eq(confirm_plan(plan), Ok(true))
}

///|
test "mixed workspace as-is selections are no-op without edits" {
  let bumps : Array[@model.WorkspaceBump] = [
    {
      path: "packages/a/moon.mod",
      current_version: "1.0.0",
      release: Exact("1.0.0"),
      new_version: "1.0.0",
    },
    {
      path: "packages/b/moon.mod",
      current_version: "2.0.0",
      release: Exact("2.0.0"),
      new_version: "2.0.0",
    },
  ]
  let plan : @model.ReleasePlan = {
    options: {
      ..@model.Options::default(),
      workspace: true,
      workspace_bumps: bumps,
      quiet: true,
    },
    current_version: "1.0.0",
    new_version: "workspace",
    edits: [],
    skipped_files: ["packages/a/moon.mod", "packages/b/moon.mod"],
    commit_message: None,
    tag_name: None,
    scripts: @model.LifecycleScripts::empty(),
  }
  assert_true(plan.is_noop())
  assert_eq(confirm_plan(plan), Ok(true))
}
