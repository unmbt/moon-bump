pub async fn parse_args() -> @config.Options {
  let args = ["mock_args"] // TODO: Use env.args() when env package is available
  
  let mut config_path = None
  let mut i = 1
  while i < args.length() {
    if args[i] == "--configFilePath" {
      if i + 1 < args.length() {
        config_path = Some(args[i + 1])
      }
    }
    i = i + 1
  }

  let mut options = @config.load_bump_config(config_path)
  i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--release" {
      if i + 1 < args.length() {
        options = { ..options, release: Some(args[i + 1]) }
        i = i + 1
      }
    } else if arg == "--preid" {
      if i + 1 < args.length() {
        options = { ..options, preid: args[i + 1] }
        i = i + 1
      }
    } else if arg == "--all" || arg == "-a" {
      options = { ..options, all: true }
    } else if arg == "--commit" || arg == "-c" {
      if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
        options = { ..options, commit: Some(args[i + 1]) }
        i = i + 1
      } else {
        options = { ..options, commit: Some("") }
      }
    } else if arg == "--no-commit" {
      options = { ..options, commit: None }
    } else if arg == "--tag" || arg == "-t" {
      if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
        options = { ..options, tag: Some(args[i + 1]) }
        i = i + 1
      } else {
        options = { ..options, tag: Some("") }
      }
    } else if arg == "--no-tag" {
      options = { ..options, tag: None }
    } else if arg == "--push" || arg == "-p" {
      options = { ..options, push: true }
    } else if arg == "--no-push" {
      options = { ..options, push: false }
    } else if arg == "--yes" || arg == "-y" {
      options = { ..options, confirm: false }
    } else if arg == "--recursive" || arg == "-r" {
      options = { ..options, recursive: true }
    } else if arg == "--execute" || arg == "-x" {
      if i + 1 < args.length() {
        options = { ..options, execute: Some(args[i + 1]) }
        i = i + 1
      }
    } else if arg.has_prefix("-") {
      // Ignore other flags
    } else {
      if options.release == None {
        match arg {
          "major" | "minor" | "patch" | "prerelease" | "premajor" | "preminor" | "prepatch" => {
            options = { ..options, release: Some(arg) }
          }
          _ => {
            match @semver.try_parse(arg) {
              Ok(_) => options = { ..options, release: Some(arg) }
              Err(_) => options.files.push(arg)
            }
          }
        }
      } else {
        options.files.push(arg)
      }
    }
    i = i + 1
  }
  options
}
