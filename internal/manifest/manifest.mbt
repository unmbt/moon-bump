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
fn relative_path(cwd : String, path : String) -> String {
  let normalized_cwd = cwd.replace_all(old="\\", new="/")
  let normalized_path = path.replace_all(old="\\", new="/")
  if normalized_cwd == "." {
    if normalized_path.has_prefix("./") {
      normalized_path[2:].to_owned()
    } else {
      normalized_path
    }
  } else {
    let prefix = if normalized_cwd.has_suffix("/") {
      normalized_cwd
    } else {
      normalized_cwd + "/"
    }
    if normalized_path.has_prefix(prefix) {
      normalized_path[prefix.length():].to_owned()
    } else {
      normalized_path
    }
  }
}

///|
fn token_text(chars : Array[Char], token : @toml.TomlToken) -> String {
  String::from_array(chars[token.from:token.to])
}

///|
fn decode_string(raw : String) -> Result[String, @model.AppError] {
  if raw.length() < 2 {
    return Err(Manifest("unterminated string"))
  }
  if raw.has_prefix("'''") || raw.has_prefix("\"\"\"") {
    return Err(Manifest("multiline strings are not supported here"))
  }
  if raw[0] == '\'' && raw[raw.length() - 1] == '\'' {
    return Ok(raw[1:raw.length() - 1].to_owned())
  }
  if raw[0] == '"' && raw[raw.length() - 1] == '"' {
    let decoded = @json.parse(raw) catch {
      error =>
        return Err(Manifest("invalid escaped string `\{raw}`: \{Repr(error)}"))
    }
    match decoded {
      String(value) => return Ok(value)
      _ => ()
    }
  }
  Err(Manifest("invalid quoted string `\{raw}`"))
}

///|
fn next_on_line(tokens : Array[@toml.TomlToken], start : Int) -> Int? {
  for i in start..<tokens.length() {
    match tokens[i].token_type {
      Whitespace | Comment => ()
      Newline => return None
      _ => return Some(i)
    }
  }
  None
}

///|
fn find_version_token(
  content : String,
) -> Result[@toml.TomlToken, @model.AppError] {
  let chars = content.to_array()
  let tokenizer = @toml.TomlTokenizer::new(content)
  let tokens = []
  while tokenizer.next_token() is Some(token) {
    tokens.push(token)
  }
  let mut at_line_start = true
  let mut brace_depth = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut in_table = false
  let found = []
  for i, token in tokens {
    let raw = token_text(chars, token)
    match token.token_type {
      Newline => {
        at_line_start = true
        continue
      }
      Whitespace | Comment => continue
      TableHeader | ArrayTable => in_table = true
      _ => ()
    }
    let is_key = match token.token_type {
      Key => raw == "version"
      String =>
        match decode_string(raw) {
          Ok(value) => value == "version"
          Err(_) => false
        }
      _ => false
    }
    if at_line_start &&
      !in_table &&
      brace_depth == 0 &&
      bracket_depth == 0 &&
      paren_depth == 0 &&
      is_key {
      let equals_index = match next_on_line(tokens, i + 1) {
        Some(value) => value
        None => return Err(Manifest("`version` has no value"))
      }
      if !(tokens[equals_index].token_type is Equals) {
        return Err(Manifest("`version` must be followed by `=`"))
      }
      let value_index = match next_on_line(tokens, equals_index + 1) {
        Some(value) => value
        None => return Err(Manifest("`version` has no value"))
      }
      if !(tokens[value_index].token_type is String) {
        return Err(Manifest("`version` must be a quoted string"))
      }
      found.push(tokens[value_index])
    }
    match token.token_type {
      BraceOpen => brace_depth += 1
      BraceClose => if brace_depth > 0 { brace_depth -= 1 }
      BracketOpen => bracket_depth += 1
      BracketClose => if bracket_depth > 0 { bracket_depth -= 1 }
      _ =>
        if token.token_type is Unknown {
          if raw == "(" {
            paren_depth += 1
          } else if raw == ")" && paren_depth > 0 {
            paren_depth -= 1
          }
        }
    }
    at_line_start = false
  }
  match found {
    [token] => Ok(token)
    [] => Err(Manifest("top-level `version` field not found"))
    _ => Err(Manifest("duplicate top-level `version` fields"))
  }
}

///|
pub fn read_version(content : String) -> Result[String, @model.AppError] {
  let token = match find_version_token(content) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  decode_string(token_text(content.to_array(), token))
}

///|
pub fn update_version(
  content : String,
  version : String,
) -> Result[String, @model.AppError] {
  let token = match find_version_token(content) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let chars = content.to_array()
  let raw = token_text(chars, token)
  let quote = if raw.has_prefix("'") { "'" } else { "\"" }
  Ok(
    String::from_array(chars[:token.from]) +
    quote +
    version +
    quote +
    String::from_array(chars[token.to:]),
  )
}

///|
fn significant_tokens(content : String) -> Array[@toml.TomlToken] {
  let tokenizer = @toml.TomlTokenizer::new(content)
  let result = []
  while tokenizer.next_token() is Some(token) {
    match token.token_type {
      Whitespace | Newline | Comment => ()
      _ => result.push(token)
    }
  }
  result
}

///|
fn parse_scripts_object(
  content : String,
  tokens : Array[@toml.TomlToken],
  open_index : Int,
) -> Result[@model.LifecycleScripts, @model.AppError] {
  let chars = content.to_array()
  let mut scripts = @model.LifecycleScripts::empty()
  let mut depth = 1
  let mut i = open_index + 1
  while i < tokens.length() && depth > 0 {
    let token = tokens[i]
    match token.token_type {
      BraceOpen => {
        depth += 1
        i += 1
      }
      BraceClose => {
        depth -= 1
        i += 1
      }
      String | Key if depth == 1 => {
        let raw_key = token_text(chars, token)
        let key = if token.token_type is String {
          match decode_string(raw_key) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
        } else {
          raw_key
        }
        if i + 2 < tokens.length() &&
          token_text(chars, tokens[i + 1]) == ":" &&
          tokens[i + 2].token_type is String {
          let value = match decode_string(token_text(chars, tokens[i + 2])) {
            Ok(decoded) => decoded
            Err(error) => return Err(error)
          }
          match key {
            "preversion" => scripts = { ..scripts, preversion: Some(value) }
            "version" => scripts = { ..scripts, version: Some(value) }
            "postversion" => scripts = { ..scripts, postversion: Some(value) }
            _ => ()
          }
          i += 3
        } else if key == "preversion" ||
          key == "version" ||
          key == "postversion" {
          return Err(Manifest("script `\{key}` must be a quoted string"))
        } else {
          i += 1
        }
      }
      _ => i += 1
    }
  }
  if depth != 0 {
    Err(Manifest("unterminated `options(scripts)` object"))
  } else {
    Ok(scripts)
  }
}

///|
pub fn read_scripts(
  content : String,
) -> Result[@model.LifecycleScripts, @model.AppError] {
  let chars = content.to_array()
  let tokens = significant_tokens(content)
  for i, token in tokens {
    if token.token_type is Key && token_text(chars, token) == "options" {
      if i + 1 >= tokens.length() || token_text(chars, tokens[i + 1]) != "(" {
        continue
      }
      let mut paren_depth = 1
      let mut j = i + 2
      while j < tokens.length() && paren_depth > 0 {
        let raw = token_text(chars, tokens[j])
        if raw == "(" {
          paren_depth += 1
        } else if raw == ")" {
          paren_depth -= 1
        } else if paren_depth == 1 &&
          tokens[j].token_type is Key &&
          raw == "scripts" &&
          j + 2 < tokens.length() &&
          token_text(chars, tokens[j + 1]) == ":" &&
          tokens[j + 2].token_type is BraceOpen {
          return parse_scripts_object(content, tokens, j + 2)
        }
        j += 1
      }
    }
  }
  Ok(@model.LifecycleScripts::empty())
}

///|
fn starts_at(haystack : Array[Char], needle : Array[Char], index : Int) -> Bool {
  if index + needle.length() > haystack.length() {
    return false
  }
  for j in 0..<needle.length() {
    if haystack[index + j] != needle[j] {
      return false
    }
  }
  true
}

///|
fn is_version_neighbor(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') || ch == '.'
}

///|
pub fn update_text_version(
  content : String,
  current : String,
  next : String,
) -> String {
  let chars = content.to_array()
  let old = current.to_array()
  if old.length() == 0 {
    return content
  }
  let builder = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    let matches = starts_at(chars, old, index)
    let before_ok = index == 0 || !is_version_neighbor(chars[index - 1])
    let end = index + old.length()
    let after_ok = end >= chars.length() || !is_version_neighbor(chars[end])
    if matches && before_ok && after_ok {
      builder.write_string(next)
      index = end
    } else {
      builder.write_char(chars[index])
      index += 1
    }
  }
  builder.to_string()
}

///|
fn is_excluded_directory(path : String) -> Bool {
  let normalized = path.replace_all(old="\\", new="/")
  let parts = normalized.split("/")
  guard parts.last() is Some(last) else { return false }
  match last {
    ".git" | "_build" | ".mooncakes" | "fixture" | "fixtures" => true
    _ => false
  }
}

///|
fn contains(values : Array[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
pub async fn discover_files(
  options : @model.Options,
) -> Result[Array[String], @model.AppError] {
  let files = []
  if options.recursive {
    @fs.walk(options.cwd, max_concurrency=1, exclude=is_excluded_directory, (
      directory,
      entries,
    ) => {
      if contains(entries, "moon.mod") {
        let path = if directory.has_suffix("/") {
          directory + "moon.mod"
        } else {
          directory + "/moon.mod"
        }
        files.push(relative_path(options.cwd, path))
      }
    }) catch {
      error => return Err(Io("failed to scan `\{options.cwd}`: \{Repr(error)}"))
    }
  } else {
    for path in options.files {
      if !contains(files, path) {
        files.push(path)
      }
    }
  }
  files.sort()
  if files.length() == 0 {
    return Err(Manifest("no files matched the release configuration"))
  }
  for path in files {
    if !@fs.exists(resolve_path(options.cwd, path)) {
      return Err(Io("file not found: `\{path}`"))
    }
  }
  Ok(files)
}

///|
async fn read_file(
  cwd : String,
  path : String,
) -> Result[String, @model.AppError] {
  let resolved = resolve_path(cwd, path)
  try {
    let data = @fs.read_file(resolved)
    Ok(data.text())
  } catch {
    error => Err(Io("failed to read `\{path}`: \{Repr(error)}"))
  }
}

///|
pub async fn inspect_manifest(
  cwd : String,
  path : String,
) -> Result[(String, @model.LifecycleScripts), @model.AppError] {
  let content = match read_file(cwd, path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let version = match read_version(content) {
    Ok(value) => value
    Err(error) => return Err(Manifest("`\{path}`: \{error.message()}"))
  }
  let scripts = match read_scripts(content) {
    Ok(value) => value
    Err(error) => return Err(Manifest("`\{path}`: \{error.message()}"))
  }
  Ok((version, scripts))
}

///|
fn is_manifest(path : String) -> Bool {
  let normalized = path.replace_all(old="\\", new="/")
  normalized == "moon.mod" || normalized.has_suffix("/moon.mod")
}

///|
pub async fn build_edit(
  cwd : String,
  path : String,
  current_version : String,
  new_version : String,
) -> Result[@model.FileEdit?, @model.AppError] {
  let content = match read_file(cwd, path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let updated = if is_manifest(path) {
    match update_version(content, new_version) {
      Ok(value) => value
      Err(error) => return Err(Manifest("`\{path}`: \{error.message()}"))
    }
  } else {
    update_text_version(content, current_version, new_version)
  }
  if updated == content {
    Ok(None)
  } else {
    Ok(Some({ path, content: updated }))
  }
}

///|
pub async fn write_edit(
  cwd : String,
  edit : @model.FileEdit,
) -> Result[Unit, @model.AppError] {
  try {
    @fs.write_file(resolve_path(cwd, edit.path), edit.content)
    Ok(())
  } catch {
    error => Err(Io("failed to write `\{edit.path}`: \{Repr(error)}"))
  }
}
