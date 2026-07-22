pub struct Commit {
  hash : String
  type_ : String
  scope : String
  message : String
}

pub async fn get_commits() -> Result[Array[Commit], String] {
  let (code, tag_data) = @process.collect_stdout("git", ["describe", "--tags", "--abbrev=0"])
  let args = if code == 0 {
    let tag = (tag_data.text() catch { _ => "" }).trim().to_owned()
    ["log", "\{tag}..HEAD", "--oneline"]
  } else {
    ["log", "--oneline"]
  }
  let (code2, log_data) = @process.collect_stdout("git", args)
  if code2 != 0 {
    return Err("Failed to get commits")
  }
  let logs = log_data.text() catch { _ => "" }
  if logs.trim().to_owned() == "" {
    return Ok([])
  }
  
  let commits = []
  let lines = logs.split("\n")
  for line in lines {
    let line_str = line.trim().to_owned()
    if line_str == "" {
      continue
    }
    
    let mut hash = ""
    let mut rest = ""
    let mut first = true
    for p in line_str.split(" ") {
      let p_str = p.to_owned()
      if first {
        hash = p_str
        first = false
      } else {
        rest = if rest == "" { p_str } else { rest + " " + p_str }
      }
    }
    
    let mut found_colon = false
    let mut type_part = ""
    let mut msg_part = ""
    
    let mut first2 = true
    for p in rest.split(":") {
      let p_str = p.to_owned()
      if first2 {
        type_part = p_str
        first2 = false
      } else {
        found_colon = true
        msg_part = if msg_part == "" { p_str } else { msg_part + ":" + p_str }
      }
    }
    
    if found_colon && type_part.length() < 20 {
      let mut word_count = 0
      for p in type_part.split(" ") {
        if p.to_owned() == "" { continue }
        word_count = word_count + 1
      }
      if word_count == 1 {
        let type_clean = type_part.trim().to_owned()
        let mut actual_type = type_clean
        let mut scope = ""
        
        let mut open_idx = -1
        let mut close_idx = -1
        let mut i = 0
        for ch in type_clean {
          if ch == '(' && open_idx == -1 {
            open_idx = i
          } else if ch == ')' && close_idx == -1 {
            close_idx = i
          }
          i = i + 1
        }
        
        if open_idx != -1 && close_idx != -1 && close_idx > open_idx {
          let mut type_buf = ""
          let mut scope_buf = ""
          i = 0
          for ch in type_clean {
            if i < open_idx {
              type_buf = type_buf + ch.to_string()
            } else if i > open_idx && i < close_idx {
              scope_buf = scope_buf + ch.to_string()
            }
            i = i + 1
          }
          actual_type = type_buf
          scope = scope_buf
        }
        
        commits.push({ hash, type_: actual_type, scope: scope, message: msg_part.trim().to_owned() })
        continue
      }
    }
    commits.push({ hash, type_: "", scope: "", message: rest })
  }
  Ok(commits)
}
