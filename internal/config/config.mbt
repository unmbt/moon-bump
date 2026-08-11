///|
fn config_error(field : String, expected : String) -> @model.AppError {
  Config("field `\{field}` must be \{expected}")
}

///|
fn bool_field(
  object : Map[String, Json],
  field : String,
) -> Result[Bool?, @model.AppError] {
  match object.get(field) {
    None => Ok(None)
    Some(True) => Ok(Some(true))
    Some(False) => Ok(Some(false))
    Some(_) => Err(config_error(field, "a boolean"))
  }
}

///|
fn string_field(
  object : Map[String, Json],
  field : String,
) -> Result[String?, @model.AppError] {
  match object.get(field) {
    None => Ok(None)
    Some(String(value)) => Ok(Some(value))
    Some(_) => Err(config_error(field, "a string"))
  }
}

///|
fn template_field(
  object : Map[String, Json],
  field : String,
) -> Result[@model.TemplateSetting?, @model.AppError] {
  match object.get(field) {
    None => Ok(None)
    Some(True) => Ok(Some(Enabled))
    Some(False) => Ok(Some(Disabled))
    Some(String(value)) => Ok(Some(Template(value)))
    Some(_) => Err(config_error(field, "a boolean or string"))
  }
}

///|
fn files_field(
  object : Map[String, Json],
) -> Result[Array[String]?, @model.AppError] {
  match object.get("files") {
    None => Ok(None)
    Some(Array(values)) => {
      let files = []
      for value in values {
        match value {
          String(path) => files.push(path)
          _ => return Err(config_error("files", "an array of strings"))
        }
      }
      Ok(Some(files))
    }
    Some(_) => Err(config_error("files", "an array of strings"))
  }
}

///|
fn parse_config(
  content : String,
  path : String,
) -> Result[@model.RawOptions, @model.AppError] {
  let parsed = @json.parse(content) catch {
    error => return Err(Config("failed to parse `\{path}`: \{Repr(error)}"))
  }
  guard parsed is Object(object) else {
    return Err(Config("`\{path}` must contain a JSON object"))
  }
  let release = match string_field(object, "release") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let preid = match string_field(object, "preid") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let commit = match template_field(object, "commit") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let tag = match template_field(object, "tag") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let sign = match bool_field(object, "sign") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let push = match bool_field(object, "push") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let update = match bool_field(object, "update") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let all = match bool_field(object, "all") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let no_git_check = match bool_field(object, "noGitCheck") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let confirm = match bool_field(object, "confirm") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let no_verify = match bool_field(object, "noVerify") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let files = match files_field(object) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let cwd = match string_field(object, "cwd") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let ignore_scripts = match bool_field(object, "ignoreScripts") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let recursive = match bool_field(object, "recursive") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let print_commits = match bool_field(object, "printCommits") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let quiet = match bool_field(object, "quiet") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let current_version = match string_field(object, "currentVersion") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let execute = match string_field(object, "execute") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    release,
    preid,
    commit,
    tag,
    sign,
    push,
    update,
    all,
    no_git_check,
    confirm,
    no_verify,
    files,
    cwd,
    ignore_scripts,
    recursive,
    print_commits,
    quiet,
    current_version,
    execute,
  })
}

///|
fn is_absolute(path : String) -> Bool {
  path.has_prefix("/") ||
  path.has_prefix("\\\\") ||
  (path.length() >= 3 && path[1] == ':' && (path[2] == '/' || path[2] == '\\'))
}

///|
fn resolve_path(cwd : String, path : String) -> String {
  if is_absolute(path) || cwd == "." || cwd == "" {
    path
  } else if cwd.has_suffix("/") || cwd.has_suffix("\\") {
    cwd + path
  } else {
    cwd + "/" + path
  }
}

///|
async fn load_config_file(
  config_path : String?,
  cwd : String,
) -> Result[@model.RawOptions, @model.AppError] {
  let explicit = config_path is Some(_)
  let path = config_path.unwrap_or("bump.config.json")
  let resolved = resolve_path(cwd, path)
  if !@fs.exists(resolved) {
    if explicit {
      return Err(Config("configuration file not found: `\{resolved}`"))
    }
    return Ok(@model.RawOptions::empty())
  }
  let content = try {
    let data = @fs.read_file(resolved)
    data.text()
  } catch {
    error => return Err(Config("failed to read `\{resolved}`: \{Repr(error)}"))
  }
  parse_config(content, resolved)
}

///|
fn normalize_template(
  setting : @model.TemplateSetting?,
  default_value : String,
) -> String? {
  match setting {
    None | Some(Enabled) => Some(default_value)
    Some(Disabled) => None
    Some(Template(value)) => Some(value)
  }
}

///|
pub fn normalize(
  raw : @model.RawOptions,
) -> Result[@model.Options, @model.AppError] {
  let defaults = @model.Options::default()
  let release = match raw.release {
    Some(value) =>
      match @model.parse_release(value) {
        Ok(parsed) => parsed
        Err(error) => return Err(error)
      }
    None => defaults.release
  }
  let current_version = match raw.current_version {
    Some(value) =>
      match @semver.try_parse(value) {
        Ok(version) => Some(version.to_string())
        Err(_) =>
          return Err(InvalidArgument("invalid current version: \{value}"))
      }
    None => None
  }
  let commit_template = normalize_template(raw.commit, "release: v%s")
  let tag_template = normalize_template(raw.tag, "v%s")
  let all = raw.all.unwrap_or(false)
  let no_verify = raw.no_verify.unwrap_or(false)
  let commit : @model.CommitOptions? = commit_template.map(fn(message) {
    { message, all, no_verify }
  })
  let tag : @model.TagOptions? = if commit is None {
    None
  } else {
    tag_template.map(fn(name) { { name, } })
  }
  let files_explicit = raw.files is Some(_)
  let files = raw.files.unwrap_or(["moon.mod"])
  let recursive = raw.recursive.unwrap_or(false) && !files_explicit
  Ok({
    release,
    preid: raw.preid.unwrap_or("beta"),
    commit,
    tag,
    sign: raw.sign.unwrap_or(false),
    push: commit is Some(_) && raw.push.unwrap_or(true),
    update: raw.update.unwrap_or(false),
    all,
    no_git_check: raw.no_git_check.unwrap_or(false),
    confirm: raw.confirm.unwrap_or(true),
    files,
    files_explicit,
    cwd: raw.cwd.unwrap_or("."),
    ignore_scripts: raw.ignore_scripts.unwrap_or(false),
    recursive,
    print_commits: raw.print_commits.unwrap_or(true),
    quiet: raw.quiet.unwrap_or(false),
    current_version,
    execute: raw.execute,
  })
}

///|
pub async fn load(
  cli : @model.RawOptions,
  config_path : String?,
) -> Result[@model.Options, @model.AppError] {
  let lookup_cwd = cli.cwd.unwrap_or(".")
  let configured = match load_config_file(config_path, lookup_cwd) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  normalize(configured.merge(cli))
}
