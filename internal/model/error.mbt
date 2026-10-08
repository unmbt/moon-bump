///|
pub(all) enum AppError {
  InvalidArgument(String)
  Config(String)
  Manifest(String)
  Io(String)
  Git(String)
  CommandFailed(String, Int)
  Partial(String)
  Aborted
} derive(Debug, Eq)

///|
pub extend AppError with Debug::{to_repr}

///|
pub extend AppError with Eq::{equal, not_equal}

///|
pub fn AppError::message(self : AppError) -> String {
  match self {
    InvalidArgument(message) => "Invalid argument: \{message}"
    Config(message) => "Configuration error: \{message}"
    Manifest(message) => "Manifest error: \{message}"
    Io(message) => "I/O error: \{message}"
    Git(message) => "Git error: \{message}"
    CommandFailed(command, exit_code) =>
      "Command failed with exit code \{exit_code}: \{command}"
    Partial(message) => "Release partially completed: \{message}"
    Aborted => "Aborted by user."
  }
}
