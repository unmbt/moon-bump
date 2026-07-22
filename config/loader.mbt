///|
pub async fn load_bump_config(config_path : String?) -> Options {
  let default_opt = Options::default()
  let file_to_read = match config_path {
    Some(p) => p
    None => "bump.config.json"
  }
  let content = try {
    let data = @fs.read_file(file_to_read)
    data.text()
  } catch {
    _ => return default_opt
  }

  let parsed = @json.parse(content) catch { _ => return default_opt }

  let mut opt = default_opt
  match parsed {
    Json::Object(m) => {
      match m.get("push") {
        Some(Json::True) => opt = { ..opt, push: true }
        Some(Json::False) => opt = { ..opt, push: false }
        _ => ()
      }
      match m.get("execute") {
        Some(Json::String(s)) => opt = { ..opt, execute: Some(s) }
        _ => ()
      }
      match m.get("all") {
        Some(Json::True) => opt = { ..opt, all: true }
        Some(Json::False) => opt = { ..opt, all: false }
        _ => ()
      }
      match m.get("commit") {
        Some(Json::String(s)) => opt = { ..opt, commit: Some(s) }
        Some(Json::False) => opt = { ..opt, commit: None }
        _ => ()
      }
      match m.get("tag") {
        Some(Json::String(s)) => opt = { ..opt, tag: Some(s) }
        Some(Json::False) => opt = { ..opt, tag: None }
        _ => ()
      }
      match m.get("sign") {
        Some(Json::True) => opt = { ..opt, sign: true }
        Some(Json::False) => opt = { ..opt, sign: false }
        _ => ()
      }
    }
    _ => ()
  }
  opt
}
