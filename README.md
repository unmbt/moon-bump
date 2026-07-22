<div align="center">
  <h1>🌕 moon-bump</h1>
  <p><strong>The elegant, interactive version bumping tool for MoonBit packages</strong></p>

  <p>
    <a href="https://github.com/unmbt/moon-bump/actions"><img src="https://img.shields.io/github/actions/workflow/status/unmbt/moon-bump/ci.yml?style=flat-square" alt="Build Status"></a>
    <a href="https://github.com/unmbt/moon-bump/releases"><img src="https://img.shields.io/github/v/release/unmbt/moon-bump?style=flat-square" alt="Release"></a>
    <a href="https://github.com/unmbt/moon-bump/blob/master/LICENSE"><img src="https://img.shields.io/github/license/unmbt/moon-bump?style=flat-square" alt="License"></a>
    <a href="https://github.com/unmbt/moon-bump"><img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-success" alt="Cross Platform"></a>
  </p>

  <p>
    <em>Read this in other languages: <a href="README.zh.md">简体中文</a></em>
  </p>
</div>

<br/>

`moon-bump` is a blazing fast, highly aesthetic, and interactive version bumping tool built entirely in [MoonBit](https://www.moonbitlang.com/). It is deeply inspired by [bumpp](https://github.com/antfu/bumpp), bringing the same delightful CLI experience to the MoonBit ecosystem.

## ✨ Features

- ⚡️ **Pure MoonBit**: Written entirely in MoonBit.
- 🎨 **Beautiful TUI**: Interactive and visually pleasing terminal UI out of the box.
- 🚀 **Smart Git Integration**: Automatically displays recent commits since the last release with beautiful color-coding.
- 📦 **MoonBit Ready**: Tailored specifically for MoonBit packages (`moon.mod.json`, etc.).
- 🛠️ **Fully Automated**: Handles updating versions, committing, tagging, and pushing all in one go.

## 📦 Installation

We provide installation scripts to quickly download and install the pre-compiled binary for your system.

### Linux & macOS

```bash
curl -fsSL https://raw.githubusercontent.com/unmbt/moon-bump/master/scripts/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/unmbt/moon-bump/master/scripts/install.ps1 | iex
```

> **Note**: The installation script will automatically add `~/.unmbt` to your `PATH`. You may need to restart your terminal for the changes to take effect.

## 🚀 Usage

Navigate to your MoonBit project directory and simply run:

```bash
moon-bump
```

You will be greeted with an interactive prompt to choose the next version bump:

```
? Current version 0.0.1 »
> patch       0.0.2
  minor       0.1.0
  major       1.0.0
  pre-patch   0.0.2-beta.0
  pre-minor   0.1.0-beta.0
  pre-major   1.0.0-beta.0
  as-is       0.0.1
  custom      ...  
```

### CLI Options

You can also bypass the interactive prompt or customize the behavior using CLI flags:

```bash
# Bump to a specific version directly
moon-bump 1.2.3

# Bump patch version directly
moon-bump patch

# Customize commit message and tag
moon-bump --commit "chore(release): v%s" --tag "v%s"

# Skip pushing to git remote
moon-bump --no-push

# Execute a command after bumping
moon-bump --execute "moon publish"
```

### Full Options List

| Option | Description | Default |
|--------|-------------|---------|
| `--commit`, `-c` | Commit message template (`%s` will be replaced by the version) | `release: v%s` |
| `--tag`, `-t` | Tag name template (`%s` will be replaced by the version) | `v%s` |
| `--push`, `-p` | Push the commit and tag to the remote | `true` |
| `--sign` | GPG sign the commit and tag | `false` |
| `--no-verify` | Skip git hooks during commit | `false` |
| `--all` | Stage all changed files before committing | `false` |
| `--execute`, `-x` | Command to execute after bumping but before committing | - |
| `--preid` | Identifier to be used to prefix pre-release version | `beta` |
| `--print-commits`| Display commits since the last release | `true` |

## 📄 License

[MIT](./LICENSE) License © 2026
