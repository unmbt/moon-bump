///|
pub(all) struct Options {
  release : String?
  preid : String
  commit : String? // None: false, Some(""): default true, Some(m): custom string
  tag : String?
  sign : Bool
  push : Bool
  install : Bool
  all : Bool
  no_git_check : Bool
  confirm : Bool
  no_verify : Bool
  files : Array[String]
  cwd : String
  ignore_scripts : Bool
  recursive : Bool
  print_commits : Bool
  config_file_path : String?
  execute : String?
} derive(Debug, Eq)

///|
pub fn Options::default() -> Options {
  {
    release: None,
    preid: "",
    commit: Some("release: v%s"),
    tag: Some("v%s"),
    sign: false,
    push: true,
    install: false,
    all: false,
    no_git_check: false,
    confirm: true,
    no_verify: false,
    files: ["moon.mod"],
    cwd: ".",
    ignore_scripts: false,
    recursive: false,
    print_commits: true,
    config_file_path: None,
    execute: None,
  }
}
