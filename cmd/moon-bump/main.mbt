///|
fn release_message(plan : @model.ReleasePlan) -> String? {
  if plan.is_noop() {
    None
  } else {
    Some("Released \{plan.new_version}")
  }
}

///|
async fn run_app() -> Result[Unit, @model.AppError] {
  let parsed = match @cli.parse_args() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if parsed.workspace_init {
    let args = ["work", "init"]
    for path in parsed.workspace_paths {
      args.push(path)
    }
    let cwd = parsed.raw.cwd.unwrap_or(".")
    match @process.run_checked("moon", args, cwd) {
      Ok(_) => return Ok(())
      Err(error) => return Err(error)
    }
  }
  let options = match @config.load(parsed.raw, parsed.config_path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let options = if options.workspace && options.workspace_select {
    let overview = match @workflow.inspect(options) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let member_contexts = []
    for path in overview.files {
      let member_options = {
        ..overview.options,
        files: [path],
        files_explicit: true,
        workspace_bumps: [],
      }
      let context = match @workflow.inspect(member_options) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      member_contexts.push(context)
    }
    let selected = match @cli.prompt_workspace_selection(member_contexts) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let selected_paths = selected.map(fn(bump) { bump.path })
    {
      ..overview.options,
      release: Exact(selected[0].new_version),
      files: selected_paths,
      files_explicit: true,
      workspace_select: false,
      workspace_bumps: selected,
    }
  } else {
    options
  }
  let context = match @workflow.inspect(options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if options.print_commits && !options.quiet {
    @cli.print_commits(context.commits)
  }
  let release = match options.release {
    Prompt =>
      match
        (if options.workspace {
          @cli.prompt_workspace_release(context)
        } else {
          @cli.prompt_release(context)
        }) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    value => value
  }
  let context = if options.workspace && options.workspace_bumps.length() == 0 {
    let bumps = match @workflow.resolve_workspace_bumps(context, release) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    { ..context, options: { ..context.options, workspace_bumps: bumps, }, }
  } else {
    context
  }
  let new_version = match @workflow.resolve_version(context, release) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let plan = match @workflow.build_plan(context, new_version) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let confirmed = match @cli.confirm_plan(plan) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !confirmed {
    return Err(Aborted)
  }
  match
    @workflow.execute(plan, emit=event => {
      @cli.report_progress(event, options.quiet)
    }) {
    Ok(_) => {
      if !options.quiet {
        match release_message(plan) {
          Some(message) => println(message)
          None => ()
        }
      }
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
async fn main {
  let mut old_cp = 0U
  match @env.get_env_var("OS") {
    Some(os) =>
      if os == "Windows_NT" {
        old_cp = @platform.get_console_output_cp()
        @platform.set_console_output_cp(65001U)
      }
    None => ()
  }

  let raw_result : Result[Unit, @model.AppError] = run_app() catch {
    _ if @async.is_being_cancelled() => Err(Aborted)
    error => raise error
  }
  let result : Result[Unit, @model.AppError] = if @async.is_being_cancelled() {
    Err(Aborted)
  } else {
    raw_result
  }

  if old_cp != 0U {
    @platform.set_console_output_cp(old_cp)
  }
  match result {
    Ok(_) => ()
    Err(Aborted) => {
      println("Error: Aborted.")
      @sys.exit(1)
    }
    Err(error) => {
      println("Error: \{error.message()}")
      @sys.exit(1)
    }
  }
}
