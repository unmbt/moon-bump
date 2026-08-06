///|
pub fn ReleaseType::to_string(self : ReleaseType) -> String {
  match self {
    Major => "major"
    Minor => "minor"
    Patch => "patch"
    Premajor => "premajor"
    Preminor => "preminor"
    Prepatch => "prepatch"
    Prerelease => "prerelease"
    Next => "next"
    Conventional => "conventional"
  }
}

///|
pub fn ReleaseType::is_prerelease(self : ReleaseType) -> Bool {
  match self {
    Premajor | Preminor | Prepatch | Prerelease => true
    _ => false
  }
}

///|
pub fn parse_release(value : String) -> Result[ReleaseSpec, AppError] {
  match value {
    "prompt" => Ok(Prompt)
    "major" => Ok(Bump(Major))
    "minor" => Ok(Bump(Minor))
    "patch" => Ok(Bump(Patch))
    "premajor" => Ok(Bump(Premajor))
    "preminor" => Ok(Bump(Preminor))
    "prepatch" => Ok(Bump(Prepatch))
    "prerelease" => Ok(Bump(Prerelease))
    "next" => Ok(Bump(Next))
    "conventional" => Ok(Bump(Conventional))
    exact =>
      match @semver.try_parse(exact) {
        Ok(version) => Ok(Exact(version.to_string()))
        Err(_) => Err(InvalidArgument("invalid release or version: \{exact}"))
      }
  }
}

///|
pub fn is_release_input(value : String) -> Bool {
  parse_release(value) is Ok(_)
}

///|
pub fn needs_commits(release : ReleaseSpec) -> Bool {
  match release {
    Prompt | Bump(Conventional) => true
    _ => false
  }
}

///|
fn conventional_type(commits : Array[Commit]) -> ReleaseType {
  let mut has_minor = false
  for commit in commits {
    if commit.is_breaking {
      return Major
    }
    if commit.type_ == "feat" {
      has_minor = true
    }
  }
  if has_minor {
    Minor
  } else {
    Patch
  }
}

///|
pub fn resolve_version(
  current : String,
  release : ReleaseSpec,
  preid : String,
  commits : Array[Commit],
) -> Result[String, AppError] {
  let version = match @semver.try_parse(current) {
    Ok(value) => value
    Err(_) => return Err(Manifest("invalid current version: \{current}"))
  }
  match release {
    Prompt => Err(InvalidArgument("interactive release has not been selected"))
    Exact(value) =>
      match @semver.try_parse(value) {
        Ok(exact) => Ok(exact.to_string())
        Err(_) => Err(InvalidArgument("invalid version: \{value}"))
      }
    Bump(kind) => {
      let actual = match kind {
        Next => if version.is_prerelease() { Prerelease } else { Patch }
        Conventional =>
          if version.is_prerelease() {
            Prerelease
          } else {
            conventional_type(commits)
          }
        other => other
      }
      let next = if actual.is_prerelease() {
        version.inc(actual.to_string(), identifier=preid, identifier_base=1)
      } else {
        version.inc(actual.to_string(), identifier=preid)
      }
      match next {
        Some(value) => Ok(value.to_string())
        None =>
          Err(
            InvalidArgument(
              "cannot increment \{current} as \{actual.to_string()}",
            ),
          )
      }
    }
  }
}

///|
pub fn format_version_string(template : String, version : String) -> String {
  if template.find("%s") is Some(_) {
    template.replace_all(old="%s", new=version)
  } else {
    template + version
  }
}
