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

///|
async fn must_run(command : String, args : Array[String], cwd : String) -> Unit {
  guard @process.capture(command, args, cwd) is Ok((0, _, _)) else {
    fail("command failed during test setup: \{command} \{args.join(" ")}")
  }
}

///|
async fn fresh_test_root() -> String {
  let base = "_build/moon-bump-tests/git-push-tag"
  for index = 0 {
    let candidate = if index == 0 { base } else { "\{base}-\{index}" }
    if !@fs.exists(candidate) {
      return candidate
    }
    continue index + 1
  }
}

///|
async test "push_tag uses the configured remote and pushes only one tag" {
  let root = fresh_test_root()
  @fs.mkdir(root, recursive=true)
  must_run("git", ["init", "--bare", "remote.git"], root)
  must_run("git", ["init", "repo"], root)
  let repo = root + "/repo"
  must_run("git", ["config", "user.name", "Moon Bump Test"], repo)
  must_run("git", ["config", "user.email", "moon-bump@example.invalid"], repo)
  @fs.write_file(
    repo + "/README.md",
    "release test\n",
    create_mode=CreateOrTruncate,
  )
  must_run("git", ["add", "README.md"], repo)
  must_run("git", ["commit", "-m", "initial"], repo)
  guard resolve_push_remote(repo) is Ok(default_remote) else {
    fail("expected default remote")
  }
  assert_eq(default_remote, "origin")
  must_run("git", ["remote", "add", "release", "../remote.git"], repo)
  must_run("git", ["push", "-u", "release", "HEAD"], repo)
  guard resolve_push_remote(repo) is Ok(upstream_remote) else {
    fail("expected upstream remote")
  }
  assert_eq(upstream_remote, "release")
  must_run("git", ["remote", "add", "preferred", "../remote.git"], repo)
  must_run("git", ["config", "remote.pushDefault", "preferred"], repo)
  guard resolve_push_remote(repo) is Ok(preferred_remote) else {
    fail("expected pushDefault remote")
  }
  assert_eq(preferred_remote, "preferred")
  must_run("git", ["config", "--unset", "remote.pushDefault"], repo)
  must_run("git", ["tag", "-a", "v1.0.0", "-m", "unrelated"], repo)
  must_run("git", ["tag", "-a", "v1.0.1", "-m", "release"], repo)
  guard push_tag("v1.0.1", repo) is Ok(_) else { fail("expected tag push") }
  guard @process.capture("git", ["ls-remote", "--tags", "../remote.git"], repo)
    is Ok((0, tags, _)) else {
    fail("expected remote tags")
  }
  assert_true(tags.find("refs/tags/v1.0.1") is Some(_))
  assert_true(tags.find("refs/tags/v1.0.0") is None)
}
