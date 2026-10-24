///|
/// The workspace manifest contract follows MoonBit's `moon.work` format:
/// a top-level `members` array containing relative module directories.
declare pub fn parse_workspace_members(
  content : String,
) -> Result[Array[String], @model.AppError]

///|
declare pub async fn find_workspace_root(
  cwd : String,
) -> Result[String?, @model.AppError]

///|
declare pub async fn discover_workspace_files(
  cwd : String,
) -> Result[(String, Array[String]), @model.AppError]
