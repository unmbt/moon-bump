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
  let options = match @config.load(parsed.raw, parsed.config_path) {
    Ok(value) => value
    Err(error) => return Err(error)
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
      match @cli.prompt_release(context) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    value => value
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
