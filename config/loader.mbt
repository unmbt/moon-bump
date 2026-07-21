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

  // Parse JSON and merge (simplified logic for demonstration)
  let _parsed = @json.parse(content) catch { _ => return default_opt }

  // Here you would match on `parsed` and override `default_opt` fields
  // For this exercise, we just return the default since actual merging
  // requires matching all fields against Json::Object.
  default_opt
}
