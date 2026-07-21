///|
fn pr(s : String) -> Unit {
  @tui.print_raw(s)
}

///|
fn prln(s : String) -> Unit {
  @tui.print_raw(s + "\n")
}

///|
pub fn prompt(
  current_version : String,
  preid? : String = "beta",
) -> Result[String, String] {
  let v : @semver.SemVer = @semver.parse(current_version) catch {
    _ => return Err("Invalid current version: " + current_version)
  }

  let get_inc = fn(rel : String) -> String {
    match v.inc(rel, identifier=preid) {
      Some(n) => n.to_string()
      None => ""
    }
  }

  let options = [
    ("major", get_inc("major")),
    ("minor", get_inc("minor")),
    ("patch", get_inc("patch")),
    ("pre-patch", get_inc("prepatch")),
    ("pre-minor", get_inc("preminor")),
    ("pre-major", get_inc("premajor")),
    ("as-is", current_version),
    ("custom ...", ""),
  ]

  let mut cursor = 2 // default to patch
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
          @vnode.text("Current version " + current_version + " >", bold=true),
        ]),
      )
      let mut i = 0
      while i < options.length() {
        let (name, ver) = options[i]
        let label = if ver == "" {
          let pad = " ".repeat(17 - name.length())
          pad + name
        } else {
          // Add some padding to match bumpp
          let pad = " ".repeat(13 - name.length())
          pad + name + " " + ver
        }
        if i == cursor {
          children.push(
            @vnode.row([
              @vnode.text("> ", fg="cyan"),
              @vnode.text(label, fg="cyan", bold=true),
            ]),
          )
        } else {
          children.push(@vnode.text("  " + label, fg="rgb(128,128,128)"))
        }
        i = i + 1
      }
    } else if step == 1 {
      children.push(
        @vnode.row([
          @vnode.text("? ", fg="yellow"),
          @vnode.text("Enter the new version number: ", bold=true),
          @vnode.text(custom_input),
          @vnode.text("█", fg="rgb(128,128,128)"),
        ]),
      )
    }
    let node = @vnode.column(children)
    let lines = @vnode.render_to_lines(node)
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
      @tui.InputEvent::Key(key_event) =>
        match key_event {
          @tui.KeyEvent::Char('c', @tui.KeyModifier::Ctrl) => running = false
          @tui.KeyEvent::Special(@tui.SpecialKey::Up, _) =>
            if step == 0 {
              cursor = if cursor > 0 {
                cursor - 1
              } else {
                options.length() - 1
              }
            }
          @tui.KeyEvent::Special(@tui.SpecialKey::Down, _) =>
            if step == 0 {
              cursor = if cursor < options.length() - 1 {
                cursor + 1
              } else {
                0
              }
            }
          @tui.KeyEvent::Special(@tui.SpecialKey::Enter, _) =>
            if step == 0 {
              if cursor == options.length() - 1 {
                step = 1
                need_render = true
              } else {
                selected_idx = cursor
                running = false
              }
            } else if step == 1 {
              running = false
            }
          @tui.KeyEvent::Special(@tui.SpecialKey::Backspace, _) =>
            if step == 1 && custom_input.length() > 0 {
              custom_input = custom_input[:custom_input.length() - 1].to_owned()
            } else {
              need_render = false
            }
          @tui.KeyEvent::Char(c, @tui.KeyModifier::None)
          | @tui.KeyEvent::Char(c, @tui.KeyModifier::Shift) =>
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
      for _ in 0..<lines_rendered {
        pr(@render.ansi_move_up() + "\r" + @render.ansi_clear_line())
      }
      lines_rendered = render()
    }
  }

  @tui.cleanup_stdin()
  pr(@render.ansi_show_cursor())

  if selected_idx >= 0 || (step == 1 && custom_input.length() > 0) {
    for _ in 0..<lines_rendered {
      pr(@render.ansi_move_up() + "\r" + @render.ansi_clear_line())
    }
    let answer = if step == 1 { custom_input } else { options[selected_idx].1 }
    let node = @vnode.column([
      @vnode.row([
        @vnode.text("* ", fg="green"),
        @vnode.text("Bump version ", bold=true),
        @vnode.text(answer, fg="cyan"),
      ]),
    ])
    let lines = @vnode.render_to_lines(node)
    for line in lines {
      prln(line)
    }
    Ok(answer)
  } else {
    Err("Aborted.")
  }
}
