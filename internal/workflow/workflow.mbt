///|
fn is_manifest(path : String) -> Bool {
  let normalized = path.replace_all(old="\\", new="/")
  normalized == "moon.mod" || normalized.has_suffix("/moon.mod")
}

///|
fn first_manifest(files : Array[String]) -> String? {
  for path in files {
    if is_manifest(path) {
      return Some(path)
    }
  }
  None
}

///|
pub async fn inspect(
  options : @model.Options,
) -> Result[@model.ReleaseContext, @model.AppError] {
  if !options.all && !options.no_git_check {
    let clean = match @git.check_clean(options.cwd) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if !clean {
      return Err(Git("working tree is not clean"))
    }
  }
  let files = match @manifest.discover_files(options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manifest = first_manifest(files)
  let inspected = match manifest {
    Some(path) =>
      match @manifest.inspect_manifest(options.cwd, path) {
        Ok(value) => Some(value)
        Err(error) => return Err(error)
      }
    None => None
  }
  let current_version = match options.current_version {
    Some(value) => value
    None =>
      match inspected {
        Some((version, _)) => version
        None =>
          return Err(
            Manifest(
              "no moon.mod was selected and --current-version was not provided",
            ),
          )
      }
  }
  let scripts = if options.ignore_scripts {
    @model.LifecycleScripts::empty()
  } else {
    match inspected {
      Some((_, value)) => value
      None => @model.LifecycleScripts::empty()
    }
  }
  let commits = if options.print_commits ||
    @model.needs_commits(options.release) {
    match @git.get_commits(options.cwd) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  } else {
    []
  }
  Ok({ options, files, current_version, commits, scripts })
}

///|
pub fn resolve_version(
  context : @model.ReleaseContext,
  release : @model.ReleaseSpec,
) -> Result[String, @model.AppError] {
  @model.resolve_version(
    context.current_version,
    release,
    context.options.preid,
    context.commits,
  )
}

///|
pub async fn build_plan(
  context : @model.ReleaseContext,
  new_version : String,
) -> Result[@model.ReleasePlan, @model.AppError] {
  let edits = []
  let skipped_files = []
  for path in context.files {
    match
      @manifest.build_edit(
        context.options.cwd,
        path,
        context.current_version,
        new_version,
      ) {
      Ok(Some(edit)) => edits.push(edit)
      Ok(None) => skipped_files.push(path)
      Err(error) => return Err(error)
    }
  }
  let commit_message = context.options.commit.map(fn(options) {
    @model.format_version_string(options.message, new_version)
  })
  let tag_name = context.options.tag.map(fn(options) {
    @model.format_version_string(options.name, new_version)
  })
  Ok({
    options: context.options,
    current_version: context.current_version,
    new_version,
    edits,
    skipped_files,
    commit_message,
    tag_name,
    scripts: context.scripts,
  })
}

///|
fn completed_text(completed : Array[String]) -> String {
  if completed.length() == 0 {
    "none"
  } else {
    completed.join(", ")
  }
}

///|
fn partial_failure(
  step : String,
  error : @model.AppError,
  completed : Array[String],
) -> @model.AppError {
  Partial(
    "failed during \{step}; completed local steps: \{completed_text(completed)}; cause: \{error.message()}",
  )
}

///|
async fn run_script(
  name : String,
  script : String?,
  cwd : String,
  emit : (@model.ProgressEvent) -> Unit,
  completed : Array[String],
) -> Result[Unit, @model.AppError] {
  match script {
    None => Ok(())
    Some(command) => {
      emit(ScriptStarted(name, command))
      match @process.run_shell_checked(command, cwd) {
        Ok(_) => {
          completed.push(name)
          Ok(())
        }
        Err(error) => Err(partial_failure(name, error, completed))
      }
    }
  }
}

///|
pub async fn execute(
  plan : @model.ReleasePlan,
  emit? : (@model.ProgressEvent) -> Unit = _ => (),
) -> Result[Unit, @model.AppError] {
  if plan.is_noop() {
    return Ok(())
  }
  let completed = []
  match
    run_script(
      "preversion",
      plan.scripts.preversion,
      plan.options.cwd,
      emit,
      completed,
    ) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  for edit in plan.edits {
    match @manifest.write_edit(plan.options.cwd, edit) {
      Ok(_) => {
        completed.push("updated \{edit.path}")
        emit(FileUpdated(edit.path))
      }
      Err(error) => return Err(partial_failure("file update", error, completed))
    }
  }
  for path in plan.skipped_files {
    emit(FileSkipped(path))
  }
  if plan.options.update {
    match @process.run_checked("moon", ["update"], plan.options.cwd) {
      Ok(_) => {
        completed.push("moon update")
        emit(DependenciesUpdated)
      }
      Err(error) => return Err(partial_failure("moon update", error, completed))
    }
  }
  match plan.options.execute {
    Some(command) =>
      match @process.run_shell_checked(command, plan.options.cwd) {
        Ok(_) => {
          completed.push("execute hook")
          emit(HookExecuted(command))
        }
        Err(error) =>
          return Err(partial_failure("execute hook", error, completed))
      }
    None => ()
  }
  match
    run_script(
      "version",
      plan.scripts.version,
      plan.options.cwd,
      emit,
      completed,
    ) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match (plan.options.commit, plan.commit_message) {
    (Some(commit_options), Some(message)) => {
      let files = if commit_options.all {
        ["."]
      } else {
        plan.edits.map(fn(edit) { edit.path })
      }
      match @git.add(files, plan.options.cwd) {
        Ok(_) => completed.push("git add")
        Err(error) => return Err(partial_failure("git add", error, completed))
      }
      let resolved_options = { ..commit_options, message, }
      match @git.commit(resolved_options, plan.options.cwd, plan.options.sign) {
        Ok(_) => {
          completed.push("git commit")
          emit(GitCommitted)
        }
        Err(error) =>
          return Err(partial_failure("git commit", error, completed))
      }
    }
    _ => ()
  }
  match (plan.options.tag, plan.tag_name) {
    (Some(_), Some(name)) => {
      let resolved_options : @model.TagOptions = { name, }
      match @git.tag(resolved_options, plan.options.cwd, plan.options.sign) {
        Ok(_) => {
          completed.push("git tag")
          emit(GitTagged)
        }
        Err(error) => return Err(partial_failure("git tag", error, completed))
      }
    }
    _ => ()
  }
  match
    run_script(
      "postversion",
      plan.scripts.postversion,
      plan.options.cwd,
      emit,
      completed,
    ) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if plan.options.push {
    match @git.push_commit(plan.options.cwd) {
      Ok(_) => completed.push("git push")
      Err(error) => return Err(partial_failure("git push", error, completed))
    }
    match plan.tag_name {
      Some(name) =>
        match @git.push_tag(name, plan.options.cwd) {
          Ok(_) => completed.push("git push tag")
          Err(error) =>
            return Err(partial_failure("git push tag", error, completed))
        }
      None => ()
    }
    emit(GitPushed)
  }
  Ok(())
}
