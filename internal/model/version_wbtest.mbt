///|
fn test_commit(type_ : String, breaking : Bool) -> Commit {
  {
    hash: "abc",
    type_,
    scope: "",
    description: "change",
    is_breaking: breaking,
  }
}

///|
test "release parsing validates and normalizes exact versions" {
  assert_eq(parse_release("1.2.3"), Ok(Exact("1.2.3")))
  assert_true(parse_release("not-a-version") is Err(_))
}

///|
test "standard, next, prerelease and conventional versions" {
  assert_eq(resolve_version("1.2.3", Bump(Patch), "beta", []), Ok("1.2.4"))
  assert_eq(resolve_version("1.2.3", Bump(Next), "beta", []), Ok("1.2.4"))
  assert_eq(
    resolve_version("1.2.3-beta.1", Bump(Next), "beta", []),
    Ok("1.2.3-beta.2"),
  )
  assert_eq(
    resolve_version("1.2.3", Bump(Prepatch), "rc", []),
    Ok("1.2.4-rc.1"),
  )
  assert_eq(
    resolve_version("1.2.3", Bump(Preminor), "rc", []),
    Ok("1.3.0-rc.1"),
  )
  assert_eq(
    resolve_version("1.2.3", Bump(Premajor), "rc", []),
    Ok("2.0.0-rc.1"),
  )
  assert_eq(
    resolve_version("1.2.3-rc.1", Bump(Prerelease), "rc", []),
    Ok("1.2.3-rc.2"),
  )
  assert_eq(
    resolve_version("1.2.3", Bump(Conventional), "beta", [
      test_commit("feat", false),
    ]),
    Ok("1.3.0"),
  )
  assert_eq(
    resolve_version("1.2.3", Bump(Conventional), "beta", [
      test_commit("feat", true),
    ]),
    Ok("2.0.0"),
  )
}

///|
test "version templates replace or append" {
  assert_eq(format_version_string("release: v%s", "2.0.0"), "release: v2.0.0")
  assert_eq(format_version_string("release-", "2.0.0"), "release-2.0.0")
}
