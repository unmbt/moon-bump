///|
/// The workspace manifest contract follows MoonBit's `moon.work` format:
/// a top-level `members` array containing relative module directories.
#declaration_only
pub fn parse_workspace_members(
  content : String,
) -> Result[Array[String], @model.AppError] {
  Err(@model.AppError::Manifest("workspace specification declaration"))
}

///|
#declaration_only
pub async fn find_workspace_root(
  cwd : String,
) -> Result[String?, @model.AppError] {
  Ok(None)
}

///|
#declaration_only
pub async fn discover_workspace_files(
  cwd : String,
) -> Result[(String, Array[String]), @model.AppError] {
  Err(@model.AppError::Manifest("workspace specification declaration"))
}
