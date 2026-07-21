///|
pub async fn run(options : @config.Options) -> Result[Unit, String] {
  if !options.no_git_check {
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

  let mut new_version_str = ""
  match options.release {
    Some(rel) =>
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

  println("Bumping to \{new_version_str}")

  for m in mods {
    match @fs.write_new_version(m, new_version_str) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  match options.execute {
    Some(cmd) => println("Executing hook: \{cmd}")
    // Hook execution would go here
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
      let m = if msg == "" { "release: v\{new_version_str}" } else { msg } // simple templating can be added
      match @git.commit(m) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    None => ()
  }

  match options.tag {
    Some(t) => {
      let tag_name = if t == "" { "v\{new_version_str}" } else { t }
      match @git.tag(tag_name) {
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
