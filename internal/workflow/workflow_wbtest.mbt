///|
async fn must_run(command : String, args : Array[String], cwd : String) -> Unit {
  guard @process.run_checked(command, args, cwd) is Ok(_) else {
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
async test "postversion failure stops before remote push" {
  let root = fresh_test_root()
  setup_repository(root)
  let repo = root + "/repo"
  let options = {
    ..@model.Options::default(),
    release: Bump(Patch),
    cwd: repo,
    confirm: false,
    print_commits: false,
    push: true,
  }
  guard inspect(options) is Ok(context) else {
    @fs.rmdir(root, recursive=true)
    fail("expected release context")
  }
  guard resolve_version(context, options.release) is Ok(next) else {
    @fs.rmdir(root, recursive=true)
    fail("expected next version")
  }
  guard build_plan(context, next) is Ok(plan) else {
    @fs.rmdir(root, recursive=true)
    fail("expected release plan")
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
