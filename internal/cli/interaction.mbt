///|
fn release_candidate(
  context : @model.ReleaseContext,
  release : @model.ReleaseType,
) -> String {
  match
    @model.resolve_version(
      context.current_version,
      Bump(release),
      context.options.preid,
      context.commits,
    ) {
    Ok(value) => value
    Err(_) => "unavailable"
  }
}

///|
pub fn print_commits(commits : Array[@model.Commit]) -> Unit {
  if commits.length() == 0 {
    println("No commits since the latest tag.")
    return
  }
  println("\{commits.length()} commits since the latest tag:")
  for commit in commits {
    let hash = if commit.hash.length() > 7 {
      commit.hash[:7].to_owned()
    } else {
      commit.hash
    }
    let breaking = if commit.is_breaking { "!" } else { "" }
    let header = if commit.type_ == "" {
      ""
    } else if commit.scope == "" {
      commit.type_ + breaking + ": "
    } else {
      commit.type_ + "(" + commit.scope + ")" + breaking + ": "
    }
    println("  \{hash} \{header}\{commit.description}")
  }
}

///|
pub async fn prompt_release(
  context : @model.ReleaseContext,
) -> Result[@model.ReleaseSpec, @model.AppError] {
  let choices : Array[(@model.ReleaseType, String)] = [
    (Next, "next"),
    (Conventional, "conventional"),
    (Patch, "patch"),
    (Minor, "minor"),
    (Major, "major"),
    (Prerelease, "prerelease"),
    (Prepatch, "prepatch"),
    (Preminor, "preminor"),
    (Premajor, "premajor"),
  ]
  println("Current version: \{context.current_version}")
  for index, choice in choices {
    let (release, label) = choice
    println(
      "  \{index + 1}. \{label} -> \{release_candidate(context, release)}",
    )
  }
  println("  0. keep current version")
  println("Enter a number, release type, or exact SemVer [next]:")
  let answer = @tui_io.read_line().trim().to_owned()
  if answer == "" {
    return Ok(Bump(Next))
  }
  if answer == "0" || answer == "none" || answer == "as-is" {
    return Ok(Exact(context.current_version))
  }
  let numeric = @string.parse_int(answer) catch { _ => -1 }
  if numeric >= 1 && numeric <= choices.length() {
    return Ok(Bump(choices[numeric - 1].0))
  }
  @model.parse_release(answer)
}

///|
pub async fn confirm_plan(
  plan : @model.ReleasePlan,
) -> Result[Bool, @model.AppError] {
  if !plan.options.quiet {
    println("Release \{plan.current_version} -> \{plan.new_version}")
    let files = if plan.options.all {
      "all changed files"
    } else {
      plan.edits.map(fn(edit) { edit.path }).join(", ")
    }
    println("  files: \{files}")
    match plan.commit_message {
      Some(message) => println("  commit: \{message}")
      None => ()
    }
    match plan.tag_name {
      Some(name) => println("  tag: \{name}")
      None => ()
    }
    if plan.options.push {
      println("  push: yes")
    }
  }
  if !plan.options.confirm {
    return Ok(true)
  }
  println("Continue? [Y/n]")
  let answer = @tui_io.read_line().trim().to_owned()
  Ok(
    answer == "" ||
    answer == "y" ||
    answer == "Y" ||
    answer == "yes" ||
    answer == "YES",
  )
}

///|
pub fn report_progress(event : @model.ProgressEvent, quiet : Bool) -> Unit {
  if quiet {
    return
  }
  match event {
    FileUpdated(path) => println("updated \{path}")
    FileSkipped(path) => println("skipped \{path}: version not found")
    ScriptStarted(name, command) => println("\{name}: \{command}")
    DependenciesUpdated => println("dependencies updated")
    HookExecuted(command) => println("executed: \{command}")
    GitCommitted => println("commit created")
    GitTagged => println("annotated tag created")
    GitPushed => println("commit and tags pushed")
  }
}
