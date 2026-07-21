///|
pub fn prompt(current_version : String) -> Result[String, String] {
  println("Current version is: \{current_version}")
  // TODO: implement real interactive prompt using native input reading
  Ok("0.2.0")
}
