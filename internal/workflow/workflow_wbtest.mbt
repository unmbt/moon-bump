///|
async fn must_run(command : String, args : Array[String], cwd : String) -> Unit {
  guard @process.capture(command, args, cwd) is Ok((0, _, _)) else {
    fail("command failed during test setup: \{command} \{args.join(" ")}")
  }
}

///|
async fn setup_repository(root : String) -> Unit {
  @fs.mkdir(root + "/repo", recursive=true)
  must_run("git", ["init"], root + "/repo")
  must_run("git", ["config", "user.name", "Moon Bump Test"], root + "/repo")
  must_run(
    "git",
    ["config", "user.email", "moon-bump@example.invalid"],
    root + "/repo",
  )
  @fs.write_file(
    root + "/repo/moon.mod",
    "name = \"test/repo\"\nversion = \"1.0.0\"\noptions(scripts: {\"postversion\": \"exit 9\"})\n",
    create_mode=CreateOrTruncate,
  )
  must_run("git", ["add", "moon.mod"], root + "/repo")
  must_run("git", ["commit", "-m", "initial"], root + "/repo")
}

///|
async fn fresh_test_root() -> String {
  let base = "_build/moon-bump-tests/workflow-postversion"
  for index = 0 {
    let candidate = if index == 0 { base } else { "\{base}-\{index}" }
    if !@fs.exists(candidate) {
      return candidate
    }
    continue index + 1
  }
}

///|
async fn fresh_noop_test_root() -> String {
  let base = "_build/moon-bump-tests/workflow-noop"
  for index = 0 {
    let candidate = if index == 0 { base } else { "\{base}-\{index}" }
    if !@fs.exists(candidate) {
      return candidate
    }
    continue index + 1
  }
}

///|
async test "postversion failure stops before remote push" {
  let root = fresh_test_root()
  setup_repository(root)
  let repo = root + "/repo"
  let options = {
    ..@model.Options::default(),
    release: Bump(Patch),
    cwd: repo,
    commit: None,
    tag: None,
    confirm: false,
    no_git_check: true,
    print_commits: false,
    push: true,
  }
  let context = match inspect(options) {
    Ok(value) => value
    Err(error) => fail("expected release context: \{error.message()}")
  }
  let next = match resolve_version(context, options.release) {
    Ok(value) => value
    Err(error) => fail("expected next version: \{error.message()}")
  }
  let plan = match build_plan(context, next) {
    Ok(value) => value
    Err(error) => fail("expected release plan: \{error.message()}")
  }
  let events = []
  let result = execute(plan, emit=event => events.push(event))
  guard result is Err(Partial(message)) else {
    fail("expected partial release error")
  }
  assert_true(message.find("postversion") is Some(_))
  for event in events {
    assert_true(!(event is GitPushed))
  }
}

///|
async test "as-is plan skips scripts and all Git side effects" {
  let root = fresh_noop_test_root()
  setup_repository(root)
  let repo = root + "/repo"
  let options = {
    ..@model.Options::default(),
    release: Exact("1.0.0"),
    cwd: repo,
    confirm: false,
    no_git_check: true,
    print_commits: false,
    push: true,
  }
  let context = match inspect(options) {
    Ok(value) => value
    Err(error) => fail("expected release context: \{error.message()}")
  }
  let next = match resolve_version(context, options.release) {
    Ok(value) => value
    Err(error) => fail("expected unchanged version: \{error.message()}")
  }
  let plan = match build_plan(context, next) {
    Ok(value) => value
    Err(error) => fail("expected release plan: \{error.message()}")
  }
  assert_true(plan.is_noop())
  let events = []
  assert_true(execute(plan, emit=event => events.push(event)) is Ok(_))
  assert_eq(events, [])
  guard @process.capture("git", ["rev-list", "--count", "HEAD"], repo)
    is Ok((0, commit_count, _)) else {
    fail("expected commit count")
  }
  assert_eq(commit_count.trim(), "1")
  guard @process.capture("git", ["tag", "--list"], repo) is Ok((0, tags, _)) else {
    fail("expected tag list")
  }
  assert_eq(tags.trim(), "")
}
