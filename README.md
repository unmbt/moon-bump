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
- 🎨 **Guided Releases**: Interactive release selection and confirmation when no release is specified.
- 🚀 **Smart Git Integration**: Automatically displays recent commits since the last release with beautiful color-coding.
- 📦 **MoonBit Ready**: Precisely edits top-level versions in `moon.mod` and supports lifecycle scripts.
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
  next        0.0.2
  conventional 0.0.2
  pre-patch   0.0.2-beta.1
  pre-minor   0.1.0-beta.1
  pre-major   1.0.0-beta.1
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
| `[release]`, `--release` | `prompt`, `next`, `conventional`, a SemVer bump type, or an exact SemVer | `prompt` |
| `[files...]` | Files to update; `moon.mod` is edited structurally, other files use boundary-aware replacement | `moon.mod` |
| `--preid` | Prerelease identifier | `beta` |
| `--commit`, `-c` | Commit message template; a value is required | `release: v%s` |
| `--no-commit` | Disable the release commit | `false` |
| `--tag`, `-t` | Annotated tag template; a value is required | `v%s` |
| `--no-tag` | Disable tagging | `false` |
| `--sign` | Sign the commit and tag | `false` |
| `--push`, `-p` / `--no-push` | Push the commit, then tags | `true` |
| `--update` / `--no-update` | Run `moon update` after file changes | `false` |
| `--all`, `-a` | Stage all changed files | `false` |
| `--git-check` / `--no-git-check` | Require a clean working tree | `true` |
| `--verify` / `--no-verify` | Run or skip Git verification hooks | `true` |
| `--yes`, `-y` | Skip confirmation | `false` |
| `--cwd` | Working directory for files, Git, and commands | `.` |
| `--recursive`, `-r` | Find all `moon.mod` files recursively | `false` |
| `--ignore-scripts` | Ignore `preversion`, `version`, and `postversion` scripts | `false` |
| `--execute`, `-x` | Shell command after file updates and before the version script | - |
| `--current-version` | Override the version used for calculation and text replacement | - |
| `--print-commits` / `--no-print-commits` | Display commits since the latest tag | `true` |
| `--quiet`, `-q` | Suppress progress output | `false` |
| `--config`, `--configFilePath` | Explicit JSON configuration path | `bump.config.json` |

If a commit or tag template contains `%s`, every occurrence is replaced. Otherwise, the version is appended to the template.

### Configuration

Configuration priority is `defaults < bump.config.json < CLI`. A missing default file is allowed; an explicitly requested missing or invalid file is an error. Supported JSON fields are `release`, `preid`, `commit`, `tag`, `sign`, `push`, `update`, `all`, `noGitCheck`, `confirm`, `noVerify`, `files`, `cwd`, `ignoreScripts`, `recursive`, `printCommits`, `quiet`, `currentVersion`, and `execute`.

```json
{
  "release": "conventional",
  "update": true,
  "commit": "release: v%s",
  "tag": "v%s",
  "files": ["moon.mod", "README.md"]
}
```

Lifecycle scripts are read from `options(scripts)` in the primary `moon.mod`. The execution order is `preversion -> file updates -> moon update -> execute -> version -> commit -> annotated tag -> postversion -> push commit -> push tags`. Remote pushes always happen last.

## 📄 License

[MIT](./LICENSE) License © 2026
