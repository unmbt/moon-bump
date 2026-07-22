///|
pub async fn check_clean() -> Result[Bool, String] {
  let (code, output) = try {
    @process.collect_stdout("git", ["status", "--porcelain"])
  } catch {
    _ => return Err("Failed to execute git status")
  }
  if code != 0 {
    return Err("Failed to check git status")
  }
  let out_text = output.text() catch { _ => "" }
  if out_text.trim().to_owned() != "" {
    return Ok(false)
  }
  Ok(true)
}

///|
pub async fn add(files : Array[String]) -> Result[Unit, String] {
  @async.with_task_group(async fn(group) {
    try {
      let args = ["add"]
      for f in files {
        args.push(f)
      }
      let _ = @process.spawn(group, "git", args)
      Ok(())
    } catch {
      _ => Err("Git add failed")
    }
  })
}

///|
pub async fn commit(msg : String, no_verify~ : Bool = false, sign~ : Bool = false) -> Result[Unit, String] {
  @async.with_task_group(async fn(group) {
    try {
      let args = ["commit", "-m", msg]
      if no_verify { args.push("--no-verify") }
      if sign { args.push("-S") }
      let _ = @process.spawn(group, "git", args)
      Ok(())
    } catch {
      _ => Err("Git commit failed")
    }
  })
}

///|
pub async fn tag(name : String, sign~ : Bool = false) -> Result[Unit, String] {
  @async.with_task_group(async fn(group) {
    try {
      let args = ["tag", name]
      if sign { args.push("-s") }
      let _ = @process.spawn(group, "git", args)
      Ok(())
    } catch {
      _ => Err("Git tag failed")
    }
  })
}

///|
pub async fn push() -> Result[Unit, String] {
  @async.with_task_group(async fn(group) {
    try {
      let _ = @process.spawn(group, "git", ["push", "--tags"])
      let _ = @process.spawn(group, "git", ["push"])
      Ok(())
    } catch {
      _ => Err("Git push failed")
    }
  })
}
