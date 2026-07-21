pub fn check_clean() -> Result[Bool, String] {
  Ok(true) // TODO: implement full output parsing if needed
}

pub async fn add(files: Array[String]) -> Result[Unit, String] {
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

pub async fn commit(msg: String) -> Result[Unit, String] {
  @async.with_task_group(async fn(group) {
    try {
      let _ = @process.spawn(group, "git", ["commit", "-m", msg])
      Ok(())
    } catch {
      _ => Err("Git commit failed")
    }
  })
}

pub async fn tag(name: String) -> Result[Unit, String] {
  @async.with_task_group(async fn(group) {
    try {
      let _ = @process.spawn(group, "git", ["tag", name])
      Ok(())
    } catch {
      _ => Err("Git tag failed")
    }
  })
}

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
