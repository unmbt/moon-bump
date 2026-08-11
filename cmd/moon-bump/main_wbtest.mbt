///|
fn release_plan(
  new_version : String,
  edits : Array[@model.FileEdit],
) -> @model.ReleasePlan {
  {
    options: @model.Options::default(),
    current_version: "1.0.0",
    new_version,
    edits,
    skipped_files: [],
    commit_message: Some("release: v\{new_version}"),
    tag_name: Some("v\{new_version}"),
    scripts: @model.LifecycleScripts::empty(),
  }
}

///|
test "successful no-op does not produce a release message" {
  assert_eq(release_message(release_plan("1.0.0", [])), None)
  assert_eq(
    release_message(
      release_plan("1.0.1", [{ path: "moon.mod", content: "version = 1.0.1" }]),
    ),
    Some("Released 1.0.1"),
  )
}
