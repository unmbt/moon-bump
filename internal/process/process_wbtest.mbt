///|
async test "checked shell commands propagate nonzero exit codes" {
  let result = run_shell_checked("exit 7", ".")
  assert_true(result is Err(CommandFailed(_, 7)))
}

///|
async test "checked shell commands support the host platform" {
  assert_eq(run_shell_checked("exit 0", "."), Ok(()))
}
