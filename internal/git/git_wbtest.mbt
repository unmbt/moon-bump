///|
test "conventional commit parser preserves scoped breaking markers" {
  let commit = parse_commit_record("abc", "feat(parser)!: replace grammar", "")
  assert_eq(commit.type_, "feat")
  assert_eq(commit.scope, "parser")
  assert_eq(commit.description, "replace grammar")
  assert_true(commit.is_breaking)
}

///|
test "conventional commit parser detects breaking footers" {
  let commit = parse_commit_record(
    "abc", "fix: handle edge case", "Details\n\nBREAKING CHANGE: output changed",
  )
  assert_true(commit.is_breaking)
}

///|
test "non-conventional subjects remain descriptions" {
  let commit = parse_commit_record("abc", "release 1.2.3", "")
  assert_eq(commit.type_, "")
  assert_eq(commit.description, "release 1.2.3")
}
