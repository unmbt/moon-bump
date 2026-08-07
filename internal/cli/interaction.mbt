///|
fn pr(s : String) -> Unit {
  @tui.print_raw(s)
}

///|
fn prln(s : String) -> Unit {
  pr(s + "\n")
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
) -> Array[(@model.ReleaseSpec?, String, String)] {
  [
    (Some(Bump(Patch)), "patch", release_candidate(context, Patch)),
    (Some(Bump(Minor)), "minor", release_candidate(context, Minor)),
    (Some(Bump(Major)), "major", release_candidate(context, Major)),
    (Some(Bump(Next)), "next", release_candidate(context, Next)),
    (
      Some(Bump(Conventional)),
      "conventional",
      release_candidate(context, Conventional),
    ),
    (
      Some(Bump(Prerelease)),
      "prerelease",
      release_candidate(context, Prerelease),
    ),
    (Some(Bump(Prepatch)), "pre-patch", release_candidate(context, Prepatch)),
    (Some(Bump(Preminor)), "pre-minor", release_candidate(context, Preminor)),
    (Some(Bump(Premajor)), "pre-major", release_candidate(context, Premajor)),
    (Some(Exact(context.current_version)), "as-is", context.current_version),
    (None, "custom ...", ""),
  ]
}

///|
fn previous_cursor(cursor : Int, length : Int) -> Int {
  if cursor > 0 {
    cursor - 1
  } else {
    length - 1
  }
}

///|
fn next_cursor(cursor : Int, length : Int) -> Int {
  if cursor < length - 1 {
    cursor + 1
  } else {
    0
  }
}

///|
fn clear_rendered_lines(lines_rendered : Int) -> Unit {
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
fn padded_commit_type(type_label : String, max_type_len : Int) -> String {
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
#warnings("-unused_async")
pub async fn prompt_release(
  context : @model.ReleaseContext,
) -> Result[@model.ReleaseSpec, @model.AppError] {
  let choices = release_choices(context)
  let mut cursor = 0
  let mut lines_rendered = 0
  let mut running = true
  let mut selected_idx = -1
  let mut step = 0
  let mut custom_input = ""
  pr(@render.ansi_hide_cursor())
  prln("")
  prln(
    @render.ansi_bold() +
    @render.ansi_fg_cyan() +
    "Bump version" +
    @render.ansi_reset(),
  )
  prln("")
  fn render() -> Int {
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
        let text = if candidate == "" {
          " ".repeat(17 - label.length()) + label
        } else {
          " ".repeat(13 - label.length()) + label + " " + candidate
        }
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
              custom_input = custom_input[:custom_input.length() - 1].to_owned()
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
  @tui.cleanup_stdin()
  pr(@render.ansi_show_cursor())
  let answer = if selected_idx >= 0 {
    choices[selected_idx].2
  } else {
    custom_input
  }
  if selected_idx >= 0 || (step == 1 && custom_input.length() > 0) {
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
    if selected_idx >= 0 {
      match choices[selected_idx].0 {
        Some(release) => Ok(release)
        None => Err(Aborted)
      }
    } else {
      @model.parse_release(custom_input)
    }
  } else {
    Err(Aborted)
  }
}

///|
#warnings("-unused_async")
pub async fn confirm_plan(
  plan : @model.ReleasePlan,
) -> Result[Bool, @model.AppError] {
  if !plan.options.quiet {
    println("Release \{plan.current_version} -> \{plan.new_version}")
    let files = if plan.options.all {
      "all changed files"
    } else {
      plan.edits.map(fn(edit) { edit.path }).join(", ")
    }
    println("  files: \{files}")
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
  @tui.enable_raw_mode()
  let mut running = true
  let mut result = true
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
  @tui.cleanup_stdin()
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
    GitPushed => println("commit and tags pushed")
  }
}
