///|
fn git_error(operation : String, stderr : String) -> @model.AppError {
  let detail = stderr.trim().to_owned()
  if detail == "" {
    Git(operation)
  } else {
    Git("\{operation}: \{detail}")
  }
}

///|
pub async fn check_clean(cwd : String) -> Result[Bool, @model.AppError] {
  let captured = match @process.capture("git", ["status", "--porcelain"], cwd) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (exit_code, stdout, stderr) = captured
  if exit_code != 0 {
    return Err(git_error("failed to inspect working tree", stderr))
  }
  Ok(stdout.trim().to_owned() == "")
}

///|
fn parse_header(subject : String) -> (String, String, String, Bool) {
  guard subject.find(":") is Some(colon) else {
    return ("", "", subject, false)
  }
  let raw_header = subject[:colon].trim().to_owned()
  if raw_header == "" || raw_header.find(" ") is Some(_) {
    return ("", "", subject, false)
  }
  let mut header = raw_header
  let mut is_breaking = false
  if header.has_suffix("!") {
    is_breaking = true
    header = header[:header.length() - 1].to_owned()
  }
  let mut type_ = header
  let mut scope = ""
  if header.has_suffix(")") && header.find("(") is Some(open) {
    if open > 0 {
      type_ = header[:open].to_owned()
      scope = header[open + 1:header.length() - 1].to_owned()
    }
  }
  if type_ == "" {
    ("", "", subject, false)
  } else {
    (type_, scope, subject[colon + 1:].trim().to_owned(), is_breaking)
  }
}

///|
fn has_breaking_footer(body : String) -> Bool {
  for line in body.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("BREAKING CHANGE:") ||
      trimmed.has_prefix("BREAKING-CHANGE:") {
      return true
    }
  }
  false
}

///|
pub fn parse_commit_record(
  hash : String,
  subject : String,
  body : String,
) -> @model.Commit {
  let (type_, scope, description, header_breaking) = parse_header(subject)
  {
    hash,
    type_,
    scope,
    description,
    is_breaking: header_breaking || has_breaking_footer(body),
  }
}

///|
fn parse_log(output : String) -> Array[@model.Commit] {
  let field_separator = "\u{001f}"
  let record_separator = "\u{001e}"
  let commits = []
  for record in output.split(record_separator) {
    let value = record.trim().to_owned()
    if value == "" {
      continue
    }
    let fields = value.split(field_separator).to_array()
    if fields.length() < 2 {
      continue
    }
    let hash = fields[0].trim().to_owned()
    let subject = fields[1].trim().to_owned()
    let body = if fields.length() >= 3 { fields[2].to_owned() } else { "" }
    commits.push(parse_commit_record(hash, subject, body))
  }
  commits
}

///|
pub async fn get_commits(
  cwd : String,
) -> Result[Array[@model.Commit], @model.AppError] {
  let described = match
    @process.capture("git", ["describe", "--tags", "--abbrev=0"], cwd) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (tag_exit, tag_stdout, _) = described
  let args = ["log"]
  if tag_exit == 0 && tag_stdout.trim().to_owned() != "" {
    args.push("\{tag_stdout.trim()}..HEAD")
  }
  args.push("--format=%H%x1f%s%x1f%b%x1e")
  let captured = match @process.capture("git", args, cwd) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (exit_code, stdout, stderr) = captured
  if exit_code != 0 {
    return Err(git_error("failed to read commits", stderr))
  }
  Ok(parse_log(stdout))
}

///|
pub async fn add(
  files : Array[String],
  cwd : String,
) -> Result[Unit, @model.AppError] {
  let args = ["add", "--"]
  for file in files {
    args.push(file)
  }
  @process.run_checked("git", args, cwd)
}

///|
pub async fn commit(
  options : @model.CommitOptions,
  cwd : String,
  sign : Bool,
) -> Result[Unit, @model.AppError] {
  let args = ["commit", "-m", options.message]
  if options.no_verify {
    args.push("--no-verify")
  }
  if sign {
    args.push("-S")
  }
  @process.run_checked("git", args, cwd)
}

///|
pub async fn tag(
  options : @model.TagOptions,
  cwd : String,
  sign : Bool,
) -> Result[Unit, @model.AppError] {
  let args = ["tag"]
  args.push(if sign { "-s" } else { "-a" })
  args.push(options.name)
  args.push("-m")
  args.push(options.name)
  @process.run_checked("git", args, cwd)
}

///|
pub async fn push_commit(cwd : String) -> Result[Unit, @model.AppError] {
  @process.run_checked("git", ["push"], cwd)
}

///|
pub async fn push_tags(cwd : String) -> Result[Unit, @model.AppError] {
  @process.run_checked("git", ["push", "--tags"], cwd)
}
