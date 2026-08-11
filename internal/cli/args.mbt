///|
pub(all) struct ParsedArgs {
  raw : @model.RawOptions
  config_path : String?
} derive(Debug, Eq)

///|
fn app_version() -> String {
  let marker = "version = \""
  guard moon_mod.find(marker) is Some(start) else { return "unknown" }
  let rest = moon_mod[start + marker.length():]
  guard rest.find("\"") is Some(length) else { return "unknown" }
  rest[:length].to_owned()
}

///|
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some([value, ..]) => Some(value)
    _ => None
  }
}

///|
fn inverted_flag(matches : @argparse.Matches, name : String) -> Bool? {
  matches.flags.get(name).map(fn(value) { !value })
}

///|
pub fn parse_argv(
  values : Array[String],
) -> Result[ParsedArgs, @model.AppError] {
  let command = @argparse.Command(
    "moon-bump",
    version=app_version(),
    about="Reliable version releases for MoonBit projects",
    flags=[
      FlagArg("all", short='a', long="all", about="Include all changed files"),
      FlagArg(
        "git-check",
        long="git-check",
        about="Require a clean Git working tree",
        negatable=true,
      ),
      FlagArg("sign", long="sign", about="Sign the commit and tag"),
      FlagArg(
        "update",
        long="update",
        about="Run moon update after changing files",
        negatable=true,
      ),
      FlagArg(
        "push",
        short='p',
        long="push",
        about="Push the commit and release tag",
        negatable=true,
      ),
      FlagArg("yes", short='y', long="yes", about="Skip confirmation"),
      FlagArg(
        "recursive",
        short='r',
        long="recursive",
        about="Find moon.mod files recursively",
      ),
      FlagArg(
        "verify",
        long="verify",
        about="Run Git verification hooks",
        negatable=true,
      ),
      FlagArg(
        "ignore-scripts",
        long="ignore-scripts",
        about="Ignore lifecycle scripts",
      ),
      FlagArg(
        "quiet",
        short='q',
        long="quiet",
        about="Suppress progress output",
      ),
      FlagArg(
        "print-commits",
        long="print-commits",
        about="Print commits since the latest tag",
        negatable=true,
      ),
      FlagArg("no-commit", long="no-commit", about="Do not create a commit"),
      FlagArg("no-tag", long="no-tag", about="Do not create a tag"),
    ],
    options=[
      OptionArg("preid", long="preid", about="Prerelease identifier"),
      OptionArg(
        "commit",
        short='c',
        long="commit",
        about="Commit message template",
      ),
      OptionArg("tag", short='t', long="tag", about="Tag name template"),
      OptionArg(
        "current-version",
        long="current-version",
        about="Override current version",
      ),
      OptionArg("cwd", long="cwd", about="Working directory"),
      OptionArg(
        "execute",
        short='x',
        long="execute",
        about="Command to run after file updates",
      ),
      OptionArg(
        "release",
        long="release",
        about="Release type or exact version",
      ),
      OptionArg(
        "configFilePath",
        long="configFilePath",
        about="Explicit JSON configuration path",
      ),
      OptionArg(
        "config",
        long="config",
        about="Explicit JSON configuration path",
      ),
    ],
    positionals=[PositionArg("files", num_args=ValueRange(lower=0, upper=9999))],
  )
  let matches = command.parse(argv=values[:]) catch {
    error =>
      return Err(InvalidArgument("failed to parse arguments: \{Repr(error)}"))
  }
  let positional = match matches.values.get("files") {
    Some(value) => value.copy()
    None => []
  }
  let positional_release = match positional {
    [first, ..] if @model.is_release_input(first) => {
      ignore(positional.remove(0))
      Some(first)
    }
    _ => None
  }
  let release = match first_value(matches, "release") {
    Some(value) => Some(value)
    None => positional_release
  }
  let commit : @model.TemplateSetting? = if matches.flags.get("no-commit") ==
    Some(true) {
    Some(Disabled)
  } else {
    first_value(matches, "commit").map(fn(value) { Template(value) })
  }
  let tag : @model.TemplateSetting? = if matches.flags.get("no-tag") ==
    Some(true) {
    Some(Disabled)
  } else {
    first_value(matches, "tag").map(fn(value) { Template(value) })
  }
  let raw : @model.RawOptions = {
    release,
    preid: first_value(matches, "preid"),
    commit,
    tag,
    sign: matches.flags.get("sign"),
    push: matches.flags.get("push"),
    update: matches.flags.get("update"),
    all: matches.flags.get("all"),
    no_git_check: inverted_flag(matches, "git-check"),
    confirm: inverted_flag(matches, "yes"),
    no_verify: inverted_flag(matches, "verify"),
    files: if positional.length() > 0 {
      Some(positional)
    } else {
      None
    },
    cwd: first_value(matches, "cwd"),
    ignore_scripts: matches.flags.get("ignore-scripts"),
    recursive: matches.flags.get("recursive"),
    print_commits: matches.flags.get("print-commits"),
    quiet: matches.flags.get("quiet"),
    current_version: first_value(matches, "current-version"),
    execute: first_value(matches, "execute"),
  }
  let config_path = match first_value(matches, "config") {
    Some(value) => Some(value)
    None => first_value(matches, "configFilePath")
  }
  Ok({ raw, config_path })
}

///|
pub fn parse_args() -> Result[ParsedArgs, @model.AppError] {
  let argv = @env.args()
  parse_argv(if argv.length() > 1 { argv[1:].to_owned() } else { [] })
}
