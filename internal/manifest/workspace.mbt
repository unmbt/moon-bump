///|
fn workspace_error(message : String) -> @model.AppError {
  Manifest("moon.work: \{message}")
}

///|
fn workspace_path(base : String, child : String) -> String {
  if base.has_suffix("/") {
    base + child
  } else {
    base + "/" + child
  }
}

///|
fn normalize_workspace_member(raw : String) -> Result[String, @model.AppError] {
  let mut value = raw.replace_all(old="\\", new="/")
  while value.has_prefix("./") {
    value = value[2:].to_owned()
  }
  if value == "" {
    return Err(workspace_error("member paths must not be empty"))
  }
  if is_absolute(value) {
    return Err(workspace_error("member paths must be relative: `\{raw}`"))
  }
  let parts = value.split("/")
  for part in parts {
    if part == ".." {
      return Err(
        workspace_error("member paths must stay inside the workspace: `\{raw}`"),
      )
    }
  }
  while value.has_suffix("/") {
    value = value[:value.length() - 1].to_owned()
  }
  if value == "" {
    Ok(".")
  } else {
    Ok(value)
  }
}

///|
pub fn parse_workspace_members(
  content : String,
) -> Result[Array[String], @model.AppError] {
  let chars = content.to_array()
  let tokens = significant_tokens(content)
  let mut in_table = false
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i]
    match token.token_type {
      TableHeader | ArrayTable => {
        in_table = true
        i += 1
        continue
      }
      _ => ()
    }
    let is_members = !in_table &&
      (token.token_type is Key || token.token_type is String) &&
      token_text(chars, token) == "members"
    if !is_members {
      i += 1
      continue
    }
    if i + 2 >= tokens.length() {
      return Err(workspace_error("`members` must be assigned an array"))
    }
    if !(token_text(chars, tokens[i + 1]) == "=") {
      return Err(workspace_error("`members` must be followed by `=`"))
    }
    if !(tokens[i + 2].token_type is BracketOpen) {
      return Err(workspace_error("`members` must be an array"))
    }
    let members = []
    let mut expect_value = true
    let mut j = i + 3
    let mut closed = false
    while j < tokens.length() {
      let current = tokens[j]
      match current.token_type {
        String => {
          if !expect_value {
            return Err(workspace_error("members must be separated by commas"))
          }
          let raw = token_text(chars, current)
          let decoded = match decode_string(raw) {
            Ok(value) => value
            Err(error) => return Err(workspace_error(error.message()))
          }
          let member = match normalize_workspace_member(decoded) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          if contains(members, member) {
            return Err(workspace_error("duplicate member `\{member}`"))
          }
          members.push(member)
          expect_value = false
        }
        Comma => {
          if expect_value {
            return Err(workspace_error("members must contain quoted paths"))
          }
          expect_value = true
        }
        BracketClose => {
          if members.length() == 0 || (expect_value && members.length() > 0) {
            if members.length() == 0 {
              return Err(workspace_error("`members` must not be empty"))
            }
          }
          closed = true
          break
        }
        _ =>
          return Err(workspace_error("members must contain only quoted paths"))
      }
      j += 1
    }
    if !closed {
      return Err(workspace_error("unterminated `members` array"))
    }
    return Ok(members)
  }
  Err(workspace_error("top-level `members` array not found"))
}

///|
fn parent_workspace_path(path : String) -> String? {
  match path.rev_find("/") {
    None => None
    Some(index) if index == 0 => Some("/".to_owned())
    Some(index) if index == 2 && path.length() > 1 && path[1] == ':' =>
      Some(path[:3].to_owned())
    Some(index) => Some(path[:index].to_owned())
  }
}

///|
pub async fn find_workspace_root(
  cwd : String,
) -> Result[String?, @model.AppError] {
  if !@fs.exists(cwd) {
    return Ok(None)
  }
  let mut current = @fs.realpath(cwd).replace_all(old="\\", new="/")
  while true {
    if @fs.exists(workspace_path(current, "moon.work")) {
      return Ok(Some(current))
    }
    match parent_workspace_path(current) {
      None => return Ok(None)
      Some(parent) if parent == current => return Ok(None)
      Some(parent) => current = parent
    }
  }
}

///|
pub async fn discover_workspace_files(
  cwd : String,
) -> Result[(String, Array[String]), @model.AppError] {
  let root = match find_workspace_root(cwd) {
    Ok(Some(value)) => value
    Ok(None) => return Err(Manifest("moon.work not found from `\{cwd}`"))
    Err(error) => return Err(error)
  }
  let work_path = workspace_path(root, "moon.work")
  let content = @fs.read_file(work_path).text() catch {
    error => return Err(Io("failed to read `\{work_path}`: \{Repr(error)}"))
  }
  let members = match parse_workspace_members(content) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let files = []
  for member in members {
    let directory = if member == "." {
      root
    } else {
      workspace_path(root, member)
    }
    let manifest = workspace_path(directory, "moon.mod")
    if !@fs.exists(manifest) {
      return Err(Io("workspace member `\{member}` has no `moon.mod`"))
    }
    let relative = relative_path(root, manifest)
    if !contains(files, relative) {
      files.push(relative)
    }
  }
  files.sort()
  if files.length() == 0 {
    return Err(workspace_error("`members` must contain at least one module"))
  }
  Ok((root, files))
}
