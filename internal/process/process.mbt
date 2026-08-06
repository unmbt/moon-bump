///|
fn format_command(command : String, args : Array[String]) -> String {
  let builder = StringBuilder()
  builder.write_string(command)
  for arg in args {
    builder.write_string(" ")
    builder.write_string("\{Repr(arg)}")
  }
  builder.to_string()
}

///|
fn command_context(
  command : String,
  args : Array[String],
  cwd : String,
) -> String {
  "[cwd=\{cwd}] \{format_command(command, args)}"
}

///|
pub async fn run_checked(
  command : String,
  args : Array[String],
  cwd : String,
) -> Result[Unit, @model.AppError] {
  let rendered = command_context(command, args, cwd)
  let exit_code = @async_process.run(command, args, cwd~) catch {
    error => return Err(Io("failed to start \{rendered}: \{Repr(error)}"))
  }
  if exit_code == 0 {
    Ok(())
  } else {
    Err(CommandFailed(rendered, exit_code))
  }
}

///|
pub async fn capture(
  command : String,
  args : Array[String],
  cwd : String,
) -> Result[(Int, String, String), @model.AppError] {
  let rendered = command_context(command, args, cwd)
  let (exit_code, stdout, stderr) = @async_process.collect_output(
    command,
    args,
    cwd~,
  ) catch {
    error => return Err(Io("failed to start \{rendered}: \{Repr(error)}"))
  }
  let out_text = stdout.text() catch { _ => "" }
  let err_text = stderr.text() catch { _ => "" }
  Ok((exit_code, out_text, err_text))
}

///|
pub async fn run_shell_checked(
  script : String,
  cwd : String,
) -> Result[Unit, @model.AppError] {
  if @env.get_env_var("OS") == Some("Windows_NT") {
    run_checked("cmd", ["/d", "/s", "/c", script], cwd)
  } else {
    run_checked("sh", ["-c", script], cwd)
  }
}
