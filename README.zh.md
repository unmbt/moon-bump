<div align="center">
  <h1>🌕 moon-bump</h1>
  <p><strong>专为 MoonBit 包打造的优雅、交互式版本发布工具</strong></p>

  <p>
    <a href="https://github.com/unmbt/moon-bump/actions"><img src="https://img.shields.io/github/actions/workflow/status/unmbt/moon-bump/ci.yml?style=flat-square" alt="Build Status"></a>
    <a href="https://github.com/unmbt/moon-bump/releases"><img src="https://img.shields.io/github/v/release/unmbt/moon-bump?style=flat-square" alt="Release"></a>
    <a href="https://github.com/unmbt/moon-bump/blob/master/LICENSE"><img src="https://img.shields.io/github/license/unmbt/moon-bump?style=flat-square" alt="License"></a>
    <a href="https://github.com/unmbt/moon-bump"><img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-success" alt="Cross Platform"></a>
  </p>

  <p>
    <em>查看其他语言版本：<a href="README.md">English</a></em>
  </p>
</div>

<br/>

`moon-bump` 是一个基于 [MoonBit](https://www.moonbitlang.com/) 纯手工打造的极速、高颜值且可交互的版本更新工具。它深受 [bumpp](https://github.com/antfu/bumpp) 启发，致力于将同等极致的 CLI 体验带入 MoonBit 生态中。

## ✨ 特性

- ⚡️ **纯 MoonBit 打造**: 100% 使用 MoonBit 语言编写。
- 🎨 **引导式发布**: 未指定版本规则时，交互选择版本并确认发布计划。
- 🚀 **智能 Git 集成**: 自动提取并展示自上次发版以来的所有提交记录，并带有极具美感的语法高亮和颜色标记。
- 📦 **专为 MoonBit 定制**: 精确修改 `moon.mod` 顶层版本，并支持生命周期脚本。
- 🛠️ **全自动流水线**: 修改版本号、Git Commit、打 Tag、推送到远程仓库，一气呵成。

## 📦 安装指南

推荐使用 MoonBit 包管理器安装：

```bash
moon install unmbt/moon-bump/cmd/moon-bump
moon-bump -V
```

`moon install` 会将可执行文件安装到 `~/.moon/bin`。请确保该目录已加入 `PATH`。

### 预编译二进制

如果不希望从源码构建，可使用对应系统的安装脚本下载最新的 GitHub Release。

#### Linux & macOS

```bash
curl -fsSL https://raw.githubusercontent.com/unmbt/moon-bump/master/scripts/install.sh | bash
```

#### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/unmbt/moon-bump/master/scripts/install.ps1 | iex
```

> **注意**：预编译二进制安装脚本会将文件安装到 `~/.unmbt`，并将该目录加入 `PATH`。安装完成后可能需要重启终端。

## 🚀 使用方法

进入你的 MoonBit 项目根目录，然后直接运行：

```bash
moon-bump
```

你将看到一个交互式的界面，选择你需要的下一个版本号：

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

### 命令行参数

你也可以直接跳过交互式界面，或通过命令行参数进行高级定制：

```bash
# 直接升级到指定版本
moon-bump 1.2.3

# 直接升级 patch 版本
moon-bump patch

# 自定义 commit message 和 tag 格式
moon-bump --commit "chore(release): v%s" --tag "v%s"

# 跳过自动推送 (Push) 到远程
moon-bump --no-push

# 在发版前自动执行额外命令（如发布包）
moon-bump --execute "moon publish"
```

### 完整参数列表

| 选项 | 描述 | 默认值 |
|--------|-------------|---------|
| `[release]`, `--release` | `prompt`、`next`、`conventional`、SemVer 升级类型或精确版本 | `prompt` |
| `[files...]` | 要更新的文件；`moon.mod` 精确编辑，其他文件按版本边界替换 | `moon.mod` |
| `--preid` | 预发布版本标识符 | `beta` |
| `--commit`, `-c` | Commit 模板，必须提供值 | `release: v%s` |
| `--no-commit` | 不创建发布 commit | `false` |
| `--tag`, `-t` | Annotated tag 模板，必须提供值 | `v%s` |
| `--no-tag` | 不创建 tag | `false` |
| `--sign` | 签名 commit 和 tag | `false` |
| `--push`, `-p` / `--no-push` | 先推送 commit，再推送 tags | `true` |
| `--update` / `--no-update` | 文件更新后执行 `moon update` | `false` |
| `--all`, `-a` | 暂存所有修改 | `false` |
| `--git-check` / `--no-git-check` | 要求 Git 工作区干净 | `true` |
| `--verify` / `--no-verify` | 执行或跳过 Git 校验 hooks | `true` |
| `--yes`, `-y` | 跳过确认 | `false` |
| `--cwd` | 文件、Git 和外部命令的工作目录 | `.` |
| `--recursive`, `-r` | 递归查找所有 `moon.mod` | `false` |
| `--ignore-scripts` | 忽略 `preversion`、`version`、`postversion` | `false` |
| `--execute`, `-x` | 文件更新后、version 脚本前执行的 shell 命令 | - |
| `--current-version` | 覆盖版本计算和文本替换使用的当前版本 | - |
| `--print-commits` / `--no-print-commits` | 打印最新 tag 以来的提交 | `true` |
| `--quiet`, `-q` | 不输出进度信息 | `false` |
| `--config`, `--configFilePath` | 显式 JSON 配置路径 | `bump.config.json` |

Commit 或 tag 模板包含 `%s` 时会替换所有占位符，否则会把版本号追加到模板末尾。

### 配置

配置优先级为 `默认值 < bump.config.json < CLI`。默认配置不存在时使用默认值；显式指定的配置不存在、不可读或格式错误时直接失败。支持的 JSON 字段包括 `release`、`preid`、`commit`、`tag`、`sign`、`push`、`update`、`all`、`noGitCheck`、`confirm`、`noVerify`、`files`、`cwd`、`ignoreScripts`、`recursive`、`printCommits`、`quiet`、`currentVersion` 和 `execute`。

```json
{
  "release": "conventional",
  "update": true,
  "commit": "release: v%s",
  "tag": "v%s",
  "files": ["moon.mod", "README.md"]
}
```

生命周期脚本从主 `moon.mod` 的 `options(scripts)` 读取。执行顺序为 `preversion -> 文件更新 -> moon update -> execute -> version -> commit -> annotated tag -> postversion -> push commit -> push tags`，远端 push 始终最后执行。

## 📄 开源协议

[MIT](./LICENSE) License © 2026
