///|
async fn main {
  let mut old_cp = 0U
  match @env.get_env_var("OS") {
    Some(os) =>
      if os == "Windows_NT" {
        old_cp = @sys.get_console_output_cp()
        @sys.set_console_output_cp(65001U)
      }
    None => ()
  }

  let options = @cli.parse_args()
  match @core.run(options) {
    Ok(_) => ()
    Err(e) => println("Error: \{e}")
  }

  if old_cp != 0U {
    @sys.set_console_output_cp(old_cp)
  }
}
