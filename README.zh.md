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
- 🎨 **精美的 TUI**: 开箱即用的漂亮、高度交互的终端用户界面。
- 🚀 **智能 Git 集成**: 自动提取并展示自上次发版以来的所有提交记录，并带有极具美感的语法高亮和颜色标记。
- 📦 **专为 MoonBit 定制**: 无缝适配 MoonBit 项目（智能修改 `moon.mod.json` 等）。
- 🛠️ **全自动流水线**: 修改版本号、Git Commit、打 Tag、推送到远程仓库，一气呵成。

## 📦 安装指南

我们提供了一键安装脚本，帮助你快速下载并配置适合你操作系统的预编译二进制文件。

### Linux & macOS

```bash
curl -fsSL https://raw.githubusercontent.com/unmbt/moon-bump/master/scripts/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/unmbt/moon-bump/master/scripts/install.ps1 | iex
```

> **注意**：安装脚本会自动将 `~/.unmbt` 添加到你的系统 `PATH` 环境变量中。安装完成后你可能需要重启终端以使环境变量生效。

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
  pre-patch   0.0.2-beta.0
  pre-minor   0.1.0-beta.0
  pre-major   1.0.0-beta.0
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
| `--commit`, `-c` | 提交信息模板（`%s` 会被替换为新版本号） | `release: v%s` |
| `--tag`, `-t` | 标签名称模板（`%s` 会被替换为新版本号） | `v%s` |
| `--push`, `-p` | 将 commit 和 tag 推送至远程仓库 | `true` |
| `--sign` | 使用 GPG 签名你的 commit 和 tag | `false` |
| `--no-verify` | 提交时跳过 Git hooks | `false` |
| `--all` | 提交前将所有更改过的文件加入暂存区 | `false` |
| `--execute`, `-x` | 在修改版本之后、Git 提交之前执行指定的命令 | - |
| `--preid` | 预发布版本的后缀标识符 | `beta` |
| `--print-commits`| 打印上一个版本以来的 Git 提交记录 | `true` |

## 📄 开源协议

[MIT](./LICENSE) License © 2026
