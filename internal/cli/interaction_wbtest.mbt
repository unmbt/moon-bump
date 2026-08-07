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
