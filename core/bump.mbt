///|
pub async fn run(options : @config.Options) -> Result[Unit, String] {
  if !options.all && !options.no_git_check {
    match @git.check_clean() {
      Ok(is_clean) =>
        if !is_clean {
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
        let bump_type = if is_major {
          "major"
        } else if is_minor {
          "minor"
        } else {
          "patch"
        }
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

  let run_lifecycle_script = async fn(
    script_name : String,
  ) -> Result[Unit, String] {
    if options.ignore_scripts {
      return Ok(())
    }
    match @fs.get_script(script_name) {
      Ok(cmd) => {
        println("> " + cmd)
        match
          @async.with_task_group(async fn(group) {
            try {
              let _ = @process.spawn(group, "cmd", ["/c", cmd])
              Ok(())
            } catch {
              _ => {
                try {
                  let _ = @process.spawn(group, "sh", ["-c", cmd])
                  Ok(())
                } catch {
                  _ => Err("Failed to execute " + script_name)
                }
              }
            }
          }) {
          Ok(_) => Ok(())
          Err(e) => Err(e)
        }
      }
      Err(_) => Ok(())
    }
  }

  match run_lifecycle_script("preversion") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  let all_updated_files = []
  for m in mods {
    match @fs.write_new_version(m, new_version_str) {
      Ok(_) => all_updated_files.push(m)
      Err(e) => return Err(e)
    }
  }

  for f in options.files {
    if f.has_suffix("moon.mod") || f == "moon.mod" {
      continue
    }
    match @fs.update_text_file(f, current_version_str, new_version_str) {
      Ok(true) => all_updated_files.push(f)
      Ok(false) => ()
      Err(e) => return Err(e)
    }
  }

  if options.update {
    println("Updating dependencies...")
    match
      @async.with_task_group(async fn(group) {
        try {
          let _ = @process.spawn(group, "moon", ["update"])
          Ok(())
        } catch {
          _ => Err("Failed to run moon update")
        }
      }) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  match options.execute {
    Some(cmd) => {
      println("Executing hook: \{cmd}")
      match
        @async.with_task_group(async fn(group) {
          try {
            let _ = @process.spawn(group, "cmd", ["/c", cmd])
            Ok(())
          } catch {
            _ => {
              try {
                let _ = @process.spawn(group, "sh", ["-c", cmd])
                Ok(())
              } catch {
                _ => Err("Failed to execute hook")
              }
            }
          }
        }) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    None => ()
  }

  match run_lifecycle_script("version") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  let to_add = if options.all { ["."] } else { all_updated_files }

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

  match run_lifecycle_script("postversion") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  Ok(())
}
