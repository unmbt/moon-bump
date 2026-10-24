///|
test "workspace parser accepts the MoonBit members array" {
  let content = "# workspace\nmembers = [\n  \".\",\n  \"./examples\",\n]\n"
  assert_eq(parse_workspace_members(content), Ok([".", "examples"]))
}

///|
test "workspace parser rejects missing, empty, duplicate, and non-string members" {
  assert_true(parse_workspace_members("name = \"demo\"\n") is Err(_))
  assert_true(parse_workspace_members("members = []\n") is Err(_))
  assert_true(parse_workspace_members("members = [\".\", \".\"]\n") is Err(_))
  assert_true(parse_workspace_members("members = [true]\n") is Err(_))
}

///|
async test "workspace discovery walks upward and resolves member moon.mod files" {
  let root = "_build/moon-bump-tests/workspace-discovery"
  if @fs.exists(root) {
    @fs.rmdir(root, recursive=true)
  }
  @fs.mkdir(root + "/packages/a", recursive=true)
  @fs.mkdir(root + "/packages/b", recursive=true)
  @fs.write_file(
    root + "/moon.work",
    "members = [\".\", \"./packages/a\", \"packages/b\"]\n",
    create_mode=CreateOrTruncate,
  )
  for
    path in [
      root + "/moon.mod",
      root + "/packages/a/moon.mod",
      root + "/packages/b/moon.mod",
    ] {
    @fs.write_file(path, "version = \"1.0.0\"\n", create_mode=CreateOrTruncate)
  }
  guard discover_workspace_files(root + "/packages/a") is Ok((workspace, files)) else {
    fail("expected workspace discovery")
  }
  assert_true(workspace.has_suffix("workspace-discovery"))
  assert_eq(files, ["moon.mod", "packages/a/moon.mod", "packages/b/moon.mod"])
  @fs.rmdir(root, recursive=true)
}
