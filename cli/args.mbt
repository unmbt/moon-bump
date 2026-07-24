///|
fn get_version() -> String {
  let tag = "version = \""
  let s = moon_mod
  let mut i = 0
  let len = s.length()
  let tag_len = tag.length()

  while i <= len - tag_len {
    let mut match_tag = true
    let mut j = 0
    while j < tag_len {
      if s[i + j] != tag[j] {
        match_tag = false
        break
      }
      j = j + 1
    }

    if match_tag {
      let start = i + tag_len
      let mut v = ""
      let mut k = start
      while k < len {
        let ch = s[k]
        if ch.to_int().unsafe_to_char() == '"' {
          return v
        }
        v = v + ch.to_int().unsafe_to_char().to_string()
        k = k + 1
      }
    }
    i = i + 1
  }
  "0.0.1"
}

///|
pub async fn parse_args() -> @config.Options {
  let args = @env.args()
  let parse_args = if args.length() > 1 { args[1:] } else { [] }

  let cmd = @argparse.Command(
    "moon-bump",
    version=get_version(),
    about="bump version",
    flags=[
      @argparse.FlagArg("all", short='a', long="all", about="Include all files"),
      @argparse.FlagArg(
        "git-check",
        long="git-check",
        about="Run git check",
        negatable=true,
      ),
      @argparse.FlagArg("sign", long="sign", about="Sign commit and tag"),
      @argparse.FlagArg(
        "update",
        long="update",
        about="Run 'moon update' after bumping version",
      ),
      @argparse.FlagArg(
        "push",
        short='p',
        long="push",
        about="Push to remote",
        negatable=true,
      ),
      @argparse.FlagArg("yes", short='y', long="yes", about="Skip confirmation"),
      @argparse.FlagArg(
        "recursive",
        short='r',
        long="recursive",
        about="Bump package.json files recursively",
      ),
      @argparse.FlagArg(
        "verify",
        long="verify",
        about="Run git verification",
        negatable=true,
      ),
      @argparse.FlagArg(
        "ignore-scripts",
        long="ignore-scripts",
        about="Ignore scripts",
      ),
      @argparse.FlagArg("quiet", short='q', long="quiet", about="Quiet mode"),
      @argparse.FlagArg(
        "print-commits",
        long="print-commits",
        about="Print recent commits",
      ),
      @argparse.FlagArg("no-commit", long="no-commit", about="No commit"),
      @argparse.FlagArg("no-tag", long="no-tag", about="No tag"),
    ],
    options=[
      @argparse.OptionArg("preid", long="preid", about="ID for prerelease"),
      @argparse.OptionArg(
        "commit",
        short='c',
        long="commit",
        about="Commit message",
      ),
      @argparse.OptionArg("tag", short='t', long="tag", about="Tag name"),
      @argparse.OptionArg(
        "current-version",
        long="current-version",
        about="Current version",
      ),
      @argparse.OptionArg(
        "execute",
        short='x',
        long="execute",
        about="Commands to execute after version bumps",
      ),
      @argparse.OptionArg(
        "release",
        long="release",
        about="Release type or version number",
      ),
      @argparse.OptionArg(
        "configFilePath",
        long="configFilePath",
        about="Path to custom build.config file",
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "files",
        num_args=@argparse.ValueRange(lower=0, upper=9999),
      ),
    ],
  )

  let matches = cmd.parse(argv=parse_args[:]) catch {
    _ =>
      // argparse will usually print to stderr and exit if help or error.
      // But we must return something to satisfy the type system if it doesn't exit.
      return @config.Options::default()
  }

  if matches.flags.get("recursive") == Some(true) {
    let has_files = match matches.values.get("files") {
      Some(f) => f.length() > 0
      None => false
    }
    if has_files {
      let msg = @style_print.styl(
          "The --recursive option is ignored when files are specified",
        )
        .color(@style_print.rgb(255U, 255U, 0U))
        .to_ansi()
      println(msg)
    }
  }

  let config_path = match matches.values.get("configFilePath") {
    Some(v) => Some(v[0])
    None => None
  }
  let mut options = @config.load_bump_config(config_path)

  if matches.values.get("release") is Some(r) {
    options = { ..options, release: Some(r[0]) }
  }

  if matches.values.get("files") is Some(f) {
    let mut files = f
    if options.release == None && files.length() > 0 {
      let first = files[0]
      let is_release = match first {
        "major"
        | "minor"
        | "patch"
        | "prerelease"
        | "premajor"
        | "preminor"
        | "prepatch" => true
        _ =>
          match @semver.try_parse(first) {
            Ok(_) => true
            Err(_) => false
          }
      }
      if is_release {
        options = { ..options, release: Some(first) }
        files = files[1:].to_owned()
      }
    }
    options.files.append(files)
  }

  if matches.values.get("preid") is Some(p) {
    options = { ..options, preid: p[0] }
  }

  if matches.flags.get("all") == Some(true) {
    options = { ..options, all: true }
  }

  if matches.flags.get("no-commit") == Some(true) {
    options = { ..options, commit: None }
  } else if matches.values.get("commit") is Some(c) {
    options = { ..options, commit: Some(c[0]) }
  } else if matches.flags.get("commit") == Some(true) {
    options = { ..options, commit: Some("") }
  }

  if matches.flags.get("no-tag") == Some(true) {
    options = { ..options, tag: None }
  } else if matches.values.get("tag") is Some(t) {
    options = { ..options, tag: Some(t[0]) }
  } else if matches.flags.get("tag") == Some(true) {
    options = { ..options, tag: Some("") }
  }

  if matches.flags.get("push") == Some(false) {
    options = { ..options, push: false }
  } else if matches.flags.get("push") == Some(true) {
    options = { ..options, push: true }
  }

  if matches.flags.get("git-check") == Some(false) {
    options = { ..options, no_git_check: true }
  }

  if matches.flags.get("verify") == Some(false) {
    options = { ..options, no_verify: true }
  }

  if matches.flags.get("yes") == Some(true) {
    options = { ..options, confirm: false }
  }

  if matches.flags.get("recursive") == Some(true) {
    options = { ..options, recursive: true }
  }

  if matches.values.get("execute") is Some(e) {
    options = { ..options, execute: Some(e[0]) }
  }

  if matches.flags.get("update") == Some(true) {
    options = { ..options, update: true }
  }

  options
}
