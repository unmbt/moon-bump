///|
pub async fn run(options : @config.Options) -> Result[Unit, String] {
  if !(options.all) && !(options.no_git_check) {
    match @git.check_clean() {
      Ok(is_clean) =>
        if !(is_clean) {
          return Err("Git working directory not clean")
        }
      Err(e) => return Err(e)
    }
  }

  let mods = @fs.find_all_mods(options.recursive)
  if mods.length() == 0 {
    return Err("No moon.mod found")
  }

  let current_version_str = match @fs.read_current_version(mods[0]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }

  let mut commits : Array[@git.Commit] = []
  if options.print_commits || options.release == Some("conventional") {
    match @git.get_commits() {
      Ok(c) => commits = c
      Err(_) => ()
    }
  }

  if options.print_commits {
    @cli.print_commits(commits)
  }

  let mut new_version_str = ""
  match options.release {
    Some(rel) =>
      if rel == "conventional" {
        let mut is_major = false
        let mut is_minor = false
        for c in commits {
          if c.type_.has_suffix("!") || c.message.has_prefix("BREAKING CHANGE") {
            is_major = true
          } else if c.type_ == "feat" {
            is_minor = true
          }
        }
        let bump_type = if is_major { "major" } else if is_minor { "minor" } else { "patch" }
        let v = @semver.parse(current_version_str) catch {
          _ => return Err("Invalid current version")
        }
        match v.inc(bump_type, identifier=options.preid) {
          Some(n) => new_version_str = n.to_string()
          None => return Err("Failed to increment version conventionally")
        }
      } else {
        match @semver.try_parse(rel) {
          Ok(_) => new_version_str = rel
          Err(_) => {
            let v = @semver.parse(current_version_str) catch {
              _ => return Err("Invalid current version")
            }
            let next = v.inc(rel, identifier=options.preid)
            match next {
              Some(n) => new_version_str = n.to_string()
              None => return Err("Failed to increment version")
            }
          }
        }
      }
    None => {
      let default_preid = if options.preid == "" {
        "beta"
      } else {
        options.preid
      }
      new_version_str = match
        @cli.prompt(current_version_str, preid=default_preid) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
    }
  }

  match @cli.confirm_execution(current_version_str, new_version_str, options) {
    Ok(true) => ()
    Ok(false) => return Err("Aborted by user.")
    Err(e) => return Err(e)
  }

  println("Bumping to \{new_version_str}")

  for m in mods {
    match @fs.write_new_version(m, new_version_str) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  if options.install {
    println("Installing dependencies...")
    match @async.with_task_group(async fn(group) {
      try {
        let _ = @process.spawn(group, "moon", ["update"])
        Ok(())
      } catch { _ => Err("Failed to run moon update") }
    }) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  match options.execute {
    Some(cmd) => {
      println("Executing hook: \{cmd}")
      let parts = cmd.split(" ")
      let mut prog = ""
      let args = []
      let mut is_prog = true
      for p in parts {
        let ps = p.to_owned()
        if ps.length() > 0 {
          if is_prog {
            prog = ps
            is_prog = false
          } else {
            args.push(ps)
          }
        }
      }
      match
        @async.with_task_group(async fn(group) {
          try {
            let _ = @process.spawn(group, prog, args)
            Ok(())
          } catch {
            _ => Err("Failed to execute hook")
          }
        }) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    None => ()
  }

  let to_add = if options.all { ["."] } else { mods }

  if options.commit != None || options.all {
    match @git.add(to_add) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  match options.commit {
    Some(msg) => {
      let m = if msg == "" {
        "release: v\{new_version_str}"
      } else {
        msg.replace_all(old="%s", new=new_version_str)
      }
      match @git.commit(m, no_verify=options.no_verify, sign=options.sign) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    None => ()
  }

  match options.tag {
    Some(t) => {
      let tag_name = if t == "" {
        "v\{new_version_str}"
      } else {
        t.replace_all(old="%s", new=new_version_str)
      }
      match @git.tag(tag_name, sign=options.sign) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    None => ()
  }

  if options.push {
    match @git.push() {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  Ok(())
}
