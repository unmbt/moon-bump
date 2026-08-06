///|
pub(all) enum ReleaseType {
  Major
  Minor
  Patch
  Premajor
  Preminor
  Prepatch
  Prerelease
  Next
  Conventional
} derive(Debug, Eq)

///|
pub(all) enum ReleaseSpec {
  Prompt
  Exact(String)
  Bump(ReleaseType)
} derive(Debug, Eq)

///|
pub(all) enum TemplateSetting {
  Disabled
  Enabled
  Template(String)
} derive(Debug, Eq)

///|
pub(all) struct CommitOptions {
  message : String
  all : Bool
  no_verify : Bool
} derive(Debug, Eq)

///|
pub(all) struct TagOptions {
  name : String
} derive(Debug, Eq)

///|
pub(all) struct Options {
  release : ReleaseSpec
  preid : String
  commit : CommitOptions?
  tag : TagOptions?
  sign : Bool
  push : Bool
  update : Bool
  all : Bool
  no_git_check : Bool
  confirm : Bool
  files : Array[String]
  files_explicit : Bool
  cwd : String
  ignore_scripts : Bool
  recursive : Bool
  print_commits : Bool
  quiet : Bool
  current_version : String?
  execute : String?
} derive(Debug, Eq)

///|
pub fn Options::default() -> Options {
  {
    release: Prompt,
    preid: "beta",
    commit: Some({ message: "release: v%s", all: false, no_verify: false }),
    tag: Some({ name: "v%s" }),
    sign: false,
    push: true,
    update: false,
    all: false,
    no_git_check: false,
    confirm: true,
    files: ["moon.mod"],
    files_explicit: false,
    cwd: ".",
    ignore_scripts: false,
    recursive: false,
    print_commits: true,
    quiet: false,
    current_version: None,
    execute: None,
  }
}

///|
pub(all) struct RawOptions {
  release : String?
  preid : String?
  commit : TemplateSetting?
  tag : TemplateSetting?
  sign : Bool?
  push : Bool?
  update : Bool?
  all : Bool?
  no_git_check : Bool?
  confirm : Bool?
  no_verify : Bool?
  files : Array[String]?
  cwd : String?
  ignore_scripts : Bool?
  recursive : Bool?
  print_commits : Bool?
  quiet : Bool?
  current_version : String?
  execute : String?
} derive(Debug, Eq)

///|
pub fn RawOptions::empty() -> RawOptions {
  {
    release: None,
    preid: None,
    commit: None,
    tag: None,
    sign: None,
    push: None,
    update: None,
    all: None,
    no_git_check: None,
    confirm: None,
    no_verify: None,
    files: None,
    cwd: None,
    ignore_scripts: None,
    recursive: None,
    print_commits: None,
    quiet: None,
    current_version: None,
    execute: None,
  }
}

///|
fn[T] prefer(base : T?, incoming : T?) -> T? {
  match incoming {
    Some(value) => Some(value)
    None => base
  }
}

///|
pub fn RawOptions::merge(
  base : RawOptions,
  incoming : RawOptions,
) -> RawOptions {
  {
    release: prefer(base.release, incoming.release),
    preid: prefer(base.preid, incoming.preid),
    commit: prefer(base.commit, incoming.commit),
    tag: prefer(base.tag, incoming.tag),
    sign: prefer(base.sign, incoming.sign),
    push: prefer(base.push, incoming.push),
    update: prefer(base.update, incoming.update),
    all: prefer(base.all, incoming.all),
    no_git_check: prefer(base.no_git_check, incoming.no_git_check),
    confirm: prefer(base.confirm, incoming.confirm),
    no_verify: prefer(base.no_verify, incoming.no_verify),
    files: prefer(base.files, incoming.files),
    cwd: prefer(base.cwd, incoming.cwd),
    ignore_scripts: prefer(base.ignore_scripts, incoming.ignore_scripts),
    recursive: prefer(base.recursive, incoming.recursive),
    print_commits: prefer(base.print_commits, incoming.print_commits),
    quiet: prefer(base.quiet, incoming.quiet),
    current_version: prefer(base.current_version, incoming.current_version),
    execute: prefer(base.execute, incoming.execute),
  }
}

///|
pub(all) struct Commit {
  hash : String
  type_ : String
  scope : String
  description : String
  is_breaking : Bool
} derive(Debug, Eq)

///|
pub(all) struct LifecycleScripts {
  preversion : String?
  version : String?
  postversion : String?
} derive(Debug, Eq)

///|
pub fn LifecycleScripts::empty() -> LifecycleScripts {
  { preversion: None, version: None, postversion: None }
}

///|
pub(all) struct FileEdit {
  path : String
  content : String
} derive(Debug, Eq)

///|
pub(all) struct ReleaseContext {
  options : Options
  files : Array[String]
  current_version : String
  commits : Array[Commit]
  scripts : LifecycleScripts
} derive(Debug, Eq)

///|
pub(all) struct ReleasePlan {
  options : Options
  current_version : String
  new_version : String
  edits : Array[FileEdit]
  skipped_files : Array[String]
  commit_message : String?
  tag_name : String?
  scripts : LifecycleScripts
} derive(Debug, Eq)

///|
pub(all) enum ProgressEvent {
  FileUpdated(String)
  FileSkipped(String)
  ScriptStarted(String, String)
  DependenciesUpdated
  HookExecuted(String)
  GitCommitted
  GitTagged
  GitPushed
} derive(Debug, Eq)
