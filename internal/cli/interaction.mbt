///|
fn pr(s : String) -> Unit {
  @tui.print_raw(s)
}

///|
fn prln(s : String) -> Unit {
  pr(s + "\n")
}

///|
fn cleanup_terminal() -> Unit {
  @tui.cleanup_stdin()
  pr(@render.ansi_show_cursor())
}

///|
fn remove_last_char(value : String) -> String {
  let chars = value.to_array()
  let _ = chars.pop()
  String::from_array(chars)
}

///|
fn release_candidate(
  context : @model.ReleaseContext,
  release : @model.ReleaseType,
) -> String {
  match
    @model.resolve_version(
      context.current_version,
      Bump(release),
      context.options.preid,
      context.commits,
    ) {
    Ok(value) => value
    Err(_) => "unavailable"
  }
}

///|
fn release_choices(
  context : @model.ReleaseContext,
  show_candidates : Bool,
) -> Array[(@model.ReleaseSpec?, String, String)] {
  [
    (
      Some(Bump(Patch)),
      "patch",
      if show_candidates {
        release_candidate(context, Patch)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Minor)),
      "minor",
      if show_candidates {
        release_candidate(context, Minor)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Major)),
      "major",
      if show_candidates {
        release_candidate(context, Major)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Next)),
      "next",
      if show_candidates {
        release_candidate(context, Next)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Conventional)),
      "conventional",
      if show_candidates {
        release_candidate(context, Conventional)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Prerelease)),
      "prerelease",
      if show_candidates {
        release_candidate(context, Prerelease)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Prepatch)),
      "pre-patch",
      if show_candidates {
        release_candidate(context, Prepatch)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Preminor)),
      "pre-minor",
      if show_candidates {
        release_candidate(context, Preminor)
      } else {
        ""
      },
    ),
    (
      Some(Bump(Premajor)),
      "pre-major",
      if show_candidates {
        release_candidate(context, Premajor)
      } else {
        ""
      },
    ),
    (
      Some(Exact(context.current_version)),
      "as-is",
      if show_candidates {
        context.current_version
      } else {
        ""
      },
    ),
    (None, "custom ...", ""),
  ]
}

///|
fn previous_cursor(cursor : Int32, length : Int32) -> Int32 {
  if cursor > 0 {
    cursor - 1
  } else {
    length - 1
  }
}

///|
fn next_cursor(cursor : Int32, length : Int32) -> Int32 {
  if cursor < length - 1 {
    cursor + 1
  } else {
    0
  }
}

///|
fn workspace_member_label(path : String) -> String {
  if path == "moon.mod" {
    "."
  } else if path.has_suffix("/moon.mod") {
    path[:path.length() - 9].to_owned()
  } else {
    path
  }
}

///|
fn workspace_bump_for_path(
  path : String,
  bumps : Array[@model.WorkspaceBump],
) -> @model.WorkspaceBump? {
  for bump in bumps {
    if bump.path == path {
      return Some(bump)
    }
  }
  None
}

///|
fn upsert_workspace_bump(
  bumps : Array[@model.WorkspaceBump],
  replacement : @model.WorkspaceBump,
) -> Array[@model.WorkspaceBump] {
  let result = []
  let mut replaced = false
  for bump in bumps {
    if bump.path == replacement.path {
      result.push(replacement)
      replaced = true
    } else {
      result.push(bump)
    }
  }
  if !replaced {
    result.push(replacement)
  }
  result
}

///|
fn remove_workspace_bump(
  bumps : Array[@model.WorkspaceBump],
  path : String,
) -> Array[@model.WorkspaceBump] {
  bumps.filter(fn(bump) { bump.path != path })
}

///|
fn workspace_context_path(context : @model.ReleaseContext) -> String {
  match context.files {
    [path, ..] => path
    [] => "moon.mod"
  }
}

///|
fn workspace_change_text(bump : @model.WorkspaceBump) -> String {
  " " + bump.current_version + " -> " + bump.new_version
}

///|
fn clear_rendered_lines(lines_rendered : Int32) -> Unit {
  for _ in 0..<lines_rendered {
    pr(@render.ansi_move_up() + "\r" + @render.ansi_clear_line())
  }
}

///|
fn commit_type_style(type_ : String) -> (String, Bool) {
  match type_ {
    "feat" | "feature" => (@render.ansi_fg_green(), true)
    "refactor" | "style" => (@render.ansi_fg_cyan(), true)
    "docs" | "doc" | "types" | "type" => (@render.ansi_fg_blue(), true)
    "chore" | "ci" | "build" | "deps" | "dev" => (@render.ansi_fg_gray(), false)
    "fix" | "test" => (@render.ansi_fg_yellow(), true)
    "perf" => (@render.ansi_fg_magenta(), true)
    "revert" | "breaking" => (@render.ansi_fg_red(), true)
    _ => (@render.ansi_fg_white(), true)
  }
}

///|
fn ansi_text(text : String, color : String, bold : Bool) -> String {
  color +
  (if bold { @render.ansi_bold() } else { "" }) +
  text +
  @render.ansi_reset()
}

///|
fn gray_text(text : String) -> String {
  ansi_text(text, @render.ansi_fg_gray(), false)
}

///|
fn padded_commit_type(type_label : String, max_type_len : Int32) -> String {
  " ".repeat(max_type_len - type_label.length() + 1) + type_label
}

///|
pub fn print_commits(commits : Array[@model.Commit]) -> Unit {
  if commits.length() == 0 {
    prln("")
    prln(
      ansi_text("i", @render.ansi_fg_blue(), false) +
      gray_text(" No commits since the latest tag"),
    )
    prln("")
    return
  }
  prln("")
  prln(
    ansi_text(commits.length().to_string(), @render.ansi_fg_green(), true) +
    @render.ansi_bold() +
    " commits since the latest tag:" +
    @render.ansi_reset(),
  )
  prln("")
  let mut max_type_len = 0
  let mut max_scope_len = 0
  for commit in commits {
    let breaking = if commit.is_breaking { "!" } else { "" }
    let type_len = commit.type_.length() + breaking.length()
    if type_len > max_type_len {
      max_type_len = type_len
    }
    if commit.scope.length() > max_scope_len {
      max_scope_len = commit.scope.length()
    }
  }
  for commit in commits {
    let short_hash = if commit.hash.length() > 7 {
      commit.hash[:7].to_owned()
    } else {
      commit.hash
    }
    let breaking = if commit.is_breaking { "!" } else { "" }
    let type_label = commit.type_ + breaking
    let padded_type = padded_commit_type(type_label, max_type_len)
    let (type_color, type_bold) = commit_type_style(commit.type_)
    let scope = if commit.scope == "" {
      if max_scope_len > 0 {
        " ".repeat(max_scope_len + 2)
      } else {
        ""
      }
    } else {
      gray_text("(") +
      commit.scope +
      gray_text(")") +
      " ".repeat(max_scope_len - commit.scope.length())
    }
    let message = if type_bold {
      commit.description
    } else {
      gray_text(commit.description)
    }
    prln(
      gray_text(short_hash) +
      " " +
      ansi_text(padded_type, type_color, type_bold) +
      " " +
      scope +
      gray_text(":") +
      " " +
      message,
    )
  }
  prln("")
}

///|
priv enum ReleasePromptResult {
  Selected(@model.ReleaseSpec)
  Back
}

///|
fn prompt_release_mode(
  context : @model.ReleaseContext,
  show_candidates : Bool,
  show_summary : Bool,
) -> Result[ReleasePromptResult, @model.AppError] {
  let choices = release_choices(context, show_candidates)
  let mut cursor = 0
  let mut lines_rendered = 0
  let mut running = true
  let mut selected_idx = -1
  let mut step = 0
  let mut custom_input = ""
  let mut went_back = false
  pr(@render.ansi_hide_cursor())
  prln("")
  prln(
    @render.ansi_bold() +
    @render.ansi_fg_cyan() +
    "Bump version" +
    @render.ansi_reset(),
  )
  prln(gray_text("↑/↓ move  Enter select  Ctrl+C cancel"))
  prln("")
  fn render() -> Int32 {
    let children = []
    if step == 0 {
      children.push(
        @vnode.row([
          @vnode.text("? ", fg="yellow"),
          @vnode.text(
            "Current version \{context.current_version} »",
            bold=true,
          ),
        ]),
      )
      for index, choice in choices {
        let (_, label, candidate) = choice
        let suffix = if candidate == "" { "" } else { " " + candidate }
        let text = " ".repeat(13 - label.length()) + label + suffix
        if index == cursor {
          children.push(
            @vnode.row([
              @vnode.text("> ", fg="cyan"),
              @vnode.text(text, fg="cyan", bold=true),
            ]),
          )
        } else {
          children.push(@vnode.text("  " + text, fg="rgb(128,128,128)"))
        }
      }
    } else {
      children.push(
        @vnode.row([
          @vnode.text("? ", fg="yellow"),
          @vnode.text("Enter the new version number: ", bold=true),
          @vnode.text(custom_input),
          @vnode.text("█", fg="rgb(128,128,128)"),
        ]),
      )
    }
    let lines = @vnode.render_to_lines(@vnode.column(children))
    for line in lines {
      prln(line)
    }
    lines.length()
  }
  lines_rendered = render()
  @tui.enable_raw_mode()
  while running {
    let key = @tui.read_key()
    if key.length() == 0 {
      continue
    }
    let event = @tui.parse_input(key)
    let mut need_render = true
    match event {
      Key(key_event) =>
        match key_event {
          Char('c', Ctrl) => running = false
          Special(Left, _) => {
            went_back = true
            running = false
          }
          Special(Up, _) =>
            if step == 0 {
              cursor = previous_cursor(cursor, choices.length())
            }
          Special(Down, _) =>
            if step == 0 {
              cursor = next_cursor(cursor, choices.length())
            }
          Special(Enter, _) =>
            if step == 0 {
              if cursor == choices.length() - 1 {
                step = 1
              } else {
                selected_idx = cursor
                running = false
              }
            } else {
              running = false
            }
          Special(Backspace, _) =>
            if step == 1 && custom_input.length() > 0 {
              custom_input = remove_last_char(custom_input)
            } else {
              need_render = false
            }
          Char(c, None) | Char(c, Shift) =>
            if step == 1 {
              custom_input = custom_input + c.to_string()
            } else {
              need_render = false
            }
          _ => need_render = false
        }
      _ => need_render = false
    }
    if need_render && running {
      clear_rendered_lines(lines_rendered)
      lines_rendered = render()
    }
  }
  cleanup_terminal()
  if went_back {
    clear_rendered_lines(lines_rendered)
    if !show_summary {
      clear_rendered_lines(4)
    }
    return Ok(Back)
  }
  let selected_release : @model.ReleaseSpec? = if selected_idx >= 0 {
    choices[selected_idx].0
  } else {
    None
  }
  let parsed_release = match selected_release {
    Some(release) => Ok(release)
    None if step == 1 && custom_input.length() > 0 =>
      @model.parse_release(custom_input)
    None => Err(Aborted)
  }
  match parsed_release {
    Err(error) => Err(error)
    Ok(release) => {
      if show_summary {
        let answer = match
          @model.resolve_version(
            context.current_version,
            release,
            context.options.preid,
            context.commits,
          ) {
          Ok(value) => value
          Err(_) =>
            match release {
              Exact(value) => value
              _ => "unavailable"
            }
        }
        clear_rendered_lines(lines_rendered)
        let lines = @vnode.render_to_lines(
          @vnode.column([
            @vnode.row([
              @vnode.text("* ", fg="green"),
              @vnode.text("Bump version ", bold=true),
              @vnode.text(answer, fg="cyan"),
            ]),
          ]),
        )
        for line in lines {
          prln(line)
        }
      } else {
        clear_rendered_lines(lines_rendered)
        clear_rendered_lines(4)
      }
      Ok(Selected(release))
    }
  }
}

///|
pub fn prompt_release(
  context : @model.ReleaseContext,
) -> Result[@model.ReleaseSpec, @model.AppError] {
  match prompt_release_mode(context, true, true) {
    Ok(Selected(release)) => Ok(release)
    Ok(Back) => Err(Aborted)
    Err(error) => Err(error)
  }
}

///|
pub fn prompt_workspace_release(
  context : @model.ReleaseContext,
) -> Result[@model.ReleaseSpec, @model.AppError] {
  match prompt_release_mode(context, false, true) {
    Ok(Selected(release)) => Ok(release)
    Ok(Back) => Err(Aborted)
    Err(error) => Err(error)
  }
}

///|
pub fn prompt_workspace_selection(
  contexts : Array[@model.ReleaseContext],
) -> Result[Array[@model.WorkspaceBump], @model.AppError] {
  if contexts.length() == 0 {
    return Err(Manifest("workspace has no selectable members"))
  }
  let mut cursor = 0
  let mut lines_rendered = 0
  let mut running = true
  let mut cancelled = false
  let mut bumps : Array[@model.WorkspaceBump] = []
  pr(@render.ansi_hide_cursor())
  prln("")
  prln(
    @render.ansi_bold() +
    @render.ansi_fg_cyan() +
    "Select workspace releases" +
    @render.ansi_reset(),
  )
  prln(
    gray_text(
      "↑/↓ move  → choose release  ← back  Enter confirm  Delete clear",
    ),
  )
  prln("")
  fn render() -> Int32 {
    let children = []
    for index, context in contexts {
      let path = workspace_context_path(context)
      let label = workspace_member_label(path)
      let change = match workspace_bump_for_path(path, bumps) {
        Some(bump) => workspace_change_text(bump)
        None => ""
      }
      let text = label + change
      if index == cursor {
        children.push(
          @vnode.row([
            @vnode.text("> ", fg="cyan"),
            @vnode.text(text, fg="cyan", bold=true),
          ]),
        )
      } else {
        children.push(@vnode.text("  " + text, fg="rgb(128,128,128)"))
      }
    }
    let lines = @vnode.render_to_lines(@vnode.column(children))
    for line in lines {
      prln(line)
    }
    lines.length()
  }
  lines_rendered = render()
  @tui.enable_raw_mode()
  while running {
    let key = @tui.read_key()
    if key.length() == 0 {
      continue
    }
    match @tui.parse_input(key) {
      Key(key_event) =>
        match key_event {
          Char('c', Ctrl) => {
            cancelled = true
            running = false
          }
          Special(Up, _) => {
            clear_rendered_lines(lines_rendered)
            cursor = previous_cursor(cursor, contexts.length())
            lines_rendered = render()
          }
          Special(Down, _) => {
            clear_rendered_lines(lines_rendered)
            cursor = next_cursor(cursor, contexts.length())
            lines_rendered = render()
          }
          Special(Right, _) => {
            clear_rendered_lines(lines_rendered)
            match prompt_release_mode(contexts[cursor], true, false) {
              Ok(Selected(release)) => {
                let context = contexts[cursor]
                let path = workspace_context_path(context)
                let current = context.current_version
                let next = match
                  @model.resolve_version(
                    current,
                    release,
                    context.options.preid,
                    context.commits,
                  ) {
                  Ok(value) => value
                  Err(error) => {
                    cleanup_terminal()
                    return Err(error)
                  }
                }
                bumps = upsert_workspace_bump(bumps, {
                  path,
                  current_version: current,
                  release,
                  new_version: next,
                })
              }
              Ok(Back) => ()
              Err(error) => {
                cleanup_terminal()
                return Err(error)
              }
            }
            lines_rendered = render()
          }
          Special(Delete, _) | Special(Backspace, _) => {
            let path = workspace_context_path(contexts[cursor])
            bumps = remove_workspace_bump(bumps, path)
            clear_rendered_lines(lines_rendered)
            lines_rendered = render()
          }
          Special(Enter, _) => {
            if bumps.length() == 0 {
              cancelled = true
            }
            running = false
          }
          _ => ()
        }
      _ => ()
    }
  }
  cleanup_terminal()
  clear_rendered_lines(lines_rendered + 4)
  if cancelled || bumps.length() == 0 {
    Err(Aborted)
  } else {
    Ok(bumps)
  }
}

///|
pub fn confirm_plan(plan : @model.ReleasePlan) -> Result[Bool, @model.AppError] {
  if plan.is_noop() {
    if !plan.options.quiet {
      println("Version unchanged at \{plan.current_version}; nothing to do")
    }
    return Ok(true)
  }
  if !plan.options.quiet {
    if plan.options.workspace_bumps.length() > 0 {
      println("Workspace releases")
      for bump in plan.options.workspace_bumps {
        println(
          "  \{workspace_member_label(bump.path)}: \{bump.current_version} -> \{bump.new_version}",
        )
      }
    } else {
      println("Release \{plan.current_version} -> \{plan.new_version}")
      let files = if plan.options.all {
        "all changed files"
      } else {
        plan.edits.map(fn(edit) { edit.path }).join(", ")
      }
      println("  files: \{files}")
    }
    match plan.commit_message {
      Some(message) => println("  commit: \{message}")
      None => ()
    }
    match plan.tag_name {
      Some(name) => println("  tag: \{name}")
      None => ()
    }
    if plan.options.push {
      println("  push: yes")
    }
  }
  if !plan.options.confirm {
    return Ok(true)
  }
  pr(
    @render.ansi_bold() +
    @render.ansi_fg_yellow() +
    "? " +
    @render.ansi_reset() +
    @render.ansi_bold() +
    "Continue? (Y/n) " +
    @render.ansi_reset(),
  )
  let mut result = true
  @tui.enable_raw_mode()
  let mut running = true
  while running {
    let key = @tui.read_key()
    if key.length() == 0 {
      continue
    }
    match @tui.parse_input(key) {
      Key(key_event) =>
        match key_event {
          Char('y', _) | Char('Y', _) => {
            result = true
            running = false
          }
          Char('n', _) | Char('N', _) => {
            result = false
            running = false
          }
          Special(Enter, _) => {
            result = true
            running = false
          }
          Char('c', Ctrl) => {
            result = false
            running = false
          }
          _ => ()
        }
      _ => ()
    }
  }
  cleanup_terminal()
  prln(if result { "Yes" } else { "No" })
  Ok(result)
}

///|
pub fn report_progress(event : @model.ProgressEvent, quiet : Bool) -> Unit {
  if quiet {
    return
  }
  match event {
    FileUpdated(path) => println("updated \{path}")
    FileSkipped(path) => println("skipped \{path}: version not found")
    ScriptStarted(name, command) => println("\{name}: \{command}")
    DependenciesUpdated => println("dependencies updated")
    HookExecuted(command) => println("executed: \{command}")
    GitCommitted => println("commit created")
    GitTagged => println("annotated tag created")
    GitPushed => println("commit and release tag pushed")
  }
}
