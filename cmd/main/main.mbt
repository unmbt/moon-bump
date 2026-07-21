async fn main {
  let options = @cli.parse_args()
  match @core.run(options) {
    Ok(_) => ()
    Err(e) => println("Error: \{e}")
  }
}
