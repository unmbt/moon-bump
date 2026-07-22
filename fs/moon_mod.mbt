///|
fn index_of(s : String, sub : String) -> Int {
  if sub.length() == 0 {
    return 0
  }
  let mut i = 0
  while i <= s.length() - sub.length() {
    let mut j = 0
    while j < sub.length() && s[i + j] == sub[j] {
      j = j + 1
    }
    if j == sub.length() {
      return i
    }
    i = i + 1
  }
  -1
}

///|
pub async fn find_all_mods(recursive : Bool) -> Array[String] {
  if !recursive {
    return ["moon.mod"]
  }
  let (code, output) = try {
    @process.collect_stdout("git", ["ls-files"])
  } catch {
    _ => return ["moon.mod"]
  }
  if code != 0 {
    return ["moon.mod"]
  }
  let out_text = output.text() catch { _ => "" }
  let res = []
  for line in out_text.split("\n") {
    let p = line.trim().to_owned()
    if p.has_suffix("moon.mod") {
      res.push(p)
    }
  }
  if res.length() == 0 {
    ["moon.mod"]
  } else {
    res
  }
}

///|
pub async fn read_current_version(path : String) -> Result[String, String] {
  let content = try {
    let data = @fs.read_file(path)
    data.text()
  } catch {
    _ => return Err("Failed to read \{path}")
  }
  // Note: Using a simple split and search for now
  let mut current = ""
  let mut found = false
  // Because string split / lines iteration might differ, we'll try a naive approach
  // Let's use indexOf
  let key = "version = \""
  let start_idx = index_of(content, key)
  if start_idx != -1 {
    let mut i = start_idx + key.length()
    while i < content.length() && content[i] != '"' {
      i = i + 1
    }
    current = content[start_idx + key.length():i].to_owned()
    found = true
  }
  if found {
    Ok(current)
  } else {
    Err("Version not found in \{path}")
  }
}

///|
pub async fn write_new_version(
  path : String,
  new_version : String,
) -> Result[Unit, String] {
  let content = try {
    let data = @fs.read_file(path)
    data.text()
  } catch {
    _ => return Err("Failed to read \{path}")
  }

  let key = "version = \""
  let start_idx = index_of(content, key)
  if start_idx != -1 {
    let mut end_idx = start_idx + key.length()
    while end_idx < content.length() && content[end_idx] != '"' {
      end_idx = end_idx + 1
    }
    if end_idx < content.length() {
      // replace the string
      let before = content[:start_idx + key.length()].to_owned()
      let after = content[end_idx:].to_owned()
      let new_content = before + new_version + after
      try {
        @fs.write_file(path, new_content)
        return Ok(())
      } catch {
        _ => return Err("Failed to write \{path}")
      }
    }
  }
  Err("Could not find version string to replace")
}

///|
pub async fn update_text_file(path : String, old_v : String, new_v : String) -> Result[Bool, String] {
  let content = try {
    let data = @fs.read_file(path)
    data.text()
  } catch {
    _ => return Err("Failed to read \{path}")
  }
  let new_content = content.replace_all(old=old_v, new=new_v)
  if new_content != content {
    try {
      @fs.write_file(path, new_content)
      return Ok(true)
    } catch {
      _ => return Err("Failed to write \{path}")
    }
  }
  Ok(false)
}

///|
pub async fn get_script(script_name : String) -> Result[String, String] {
  let content = try {
    let data = @fs.read_file("moon.mod")
    data.text()
  } catch {
    _ => return Err("Failed to read moon.mod")
  }
  let parsed = @json.parse(content) catch { _ => return Err("Invalid json") }
  match parsed {
    Json::Object(m) => {
      match m.get("scripts") {
        Some(Json::Object(scripts)) => {
          match scripts.get(script_name) {
            Some(Json::String(cmd)) => Ok(cmd)
            _ => Err("Script not found")
          }
        }
        _ => Err("Scripts not found")
      }
    }
    _ => Err("Invalid format")
  }
}
