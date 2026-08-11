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
async test "no-op plans skip confirmation" {
  let plan : @model.ReleasePlan = {
    options: { ..@model.Options::default(), quiet: true, confirm: true },
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
