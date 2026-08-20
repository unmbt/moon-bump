# 模块设计文档

本文档详细描述了 `moon-bump` 各内部包（`internal/*`）的设计、API 和实现细节。

---

## internal/model — 数据模型与版本计算

**文件**：`error.mbt`、`types.mbt`、`version.mbt`  
**依赖**：`mizchi/semver`

model 包是整个项目的基础数据层，定义了所有共享类型、错误枚举和版本计算逻辑。它不依赖任何 I/O 操作。

### 错误类型

```moonbit
///|
pub(all) enum AppError {
  InvalidArgument(String)  // 无效参数
  Config(String)           // 配置错误
  Manifest(String)         // 清单文件错误
  Io(String)               // I/O 错误
  Git(String)              // Git 操作错误
  CommandFailed(String, Int) // 命令执行失败
  Partial(String)          // 部分完成
  Aborted                  // 用户取消
}
```

每个变体通过 `message()` 方法返回人类可读的错误消息。详见 [error-handling.md](error-handling.md)。

### 版本发布类型

```moonbit
///|
pub(all) enum ReleaseType {
  Major; Minor; Patch                      // 标准 SemVer 升级
  Premajor; Preminor; Prepatch; Prerelease // 预发布变体
  Next                                     // 智能：预发布→Prerelease，否则→Patch
  Conventional                             // 基于提交分析推导
}
```

| 方法 | 说明 |
|------|------|
| `to_string()` | 返回小写名称（如 `"major"`） |
| `is_prerelease()` | Premajor/Preminor/Prepatch/Prerelease 返回 true |

### 版本发布规格

```moonbit
///|
pub(all) enum ReleaseSpec {
  Prompt        // 交互式选择
  Exact(String) // 精确版本号
  Bump(ReleaseType) // 基于类型计算
}
```

### 模板设置（三态）

```moonbit
///|
pub(all) enum TemplateSetting {
  Disabled          // 禁用操作（--no-commit / --no-tag）
  Enabled           // 使用默认模板
  Template(String)  // 使用自定义模板
}
```

规范化流程：`Disabled → None`，`Enabled/缺省 → Some(默认值)`，`Template(v) → Some(v)`

### 配置类型

**`Options`** — 规范化后的最终配置：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `release` | `ReleaseSpec` | `Prompt` | 版本发布策略 |
| `preid` | `String` | `"beta"` | 预发布标识符 |
| `commit` | `CommitOptions?` | `Some({message: "release: v%s", ...})` | 提交配置 |
| `tag` | `TagOptions?` | `Some({name: "v%s"})` | 标签配置 |
| `sign` | `Bool` | `false` | GPG/SSH 签名 |
| `push` | `Bool` | `true` | 推送到远程 |
| `update` | `Bool` | `false` | 运行 moon update |
| `all` | `Bool` | `false` | 暂存所有文件 |
| `no_git_check` | `Bool` | `false` | 跳过工作区检查 |
| `confirm` | `Bool` | `true` | 需要用户确认 |
| `files` | `Array[String]` | `["moon.mod"]` | 要更新的文件 |
| `files_explicit` | `Bool` | `false` | 文件是否显式指定 |
| `cwd` | `String` | `"."` | 工作目录 |
| `ignore_scripts` | `Bool` | `false` | 忽略生命周期脚本 |
| `recursive` | `Bool` | `false` | 递归查找 moon.mod |
| `print_commits` | `Bool` | `true` | 打印提交记录 |
| `quiet` | `Bool` | `false` | 安静模式 |
| `current_version` | `String?` | `None` | 覆盖当前版本 |
| `execute` | `String?` | `None` | 自定义命令 |

**`RawOptions`** — 原始配置（所有字段为 `Option` 类型）：
- `empty()` — 创建全部为 `None` 的实例
- `merge(base, incoming)` — 合并两组选项，`incoming` 中的 `Some` 值覆盖 `base`

### 运行时数据结构

- **`Commit`** — Conventional Commit：`hash`、`type_`、`scope`、`description`、`is_breaking`
- **`LifecycleScripts`** — 生命周期脚本：`preversion?`、`version?`、`postversion?`
- **`FileEdit`** — 文件编辑：`path`（相对路径）、`content`（更新后的完整内容）
- **`ReleaseContext`** — 发布上下文：`options`、`files`、`current_version`、`commits`、`scripts`
- **`ReleasePlan`** — 发布计划：`options`、`current_version`、`new_version`、`edits`、`skipped_files`、`commit_message?`、`tag_name?`、`scripts`
  - `is_noop() -> Bool` — 判断版本是否未变且无文件修改
- **`ProgressEvent`** — 进度事件：`FileUpdated`、`FileSkipped`、`ScriptStarted`、`DependenciesUpdated`、`HookExecuted`、`GitCommitted`、`GitTagged`、`GitPushed`

### 版本计算函数

| 函数 | 签名 | 说明 |
|------|------|------|
| `parse_release` | `String → Result[ReleaseSpec, AppError]` | 解析版本类型字符串 |
| `is_release_input` | `String → Bool` | 检查是否为有效的版本输入 |
| `needs_commits` | `ReleaseSpec → Bool` | 是否需要提交记录（Prompt/Conventional） |
| `resolve_version` | `(current, release, preid, commits) → Result[String, AppError]` | 计算新版本号 |
| `format_version_string` | `(template, version) → String` | `%s` 替换或追加版本号 |

**`resolve_version` 逻辑**：
- `Exact(v)` → 直接使用
- `Bump(Next)` → 如果当前是预发布则 Prerelease，否则 Patch
- `Bump(Conventional)` → 如果当前是预发布则 Prerelease，否则分析提交（breaking→Major, feat→Minor, 其他→Patch）
- 使用 `@semver.inc()` 计算实际的新版本号

---

## internal/cli — 命令行界面

**文件**：`args.mbt`、`interaction.mbt`、`embedded_mod.mbt`  
**依赖**：model, `@argparse`, `@tui`, `@vnode`, `@render`, `@env`

### Pre-build 嵌入

`moon.pkg` 中配置了 pre-build 步骤：

```
options(
  "pre-build": [{
    "input": "../../moon.mod",
    "output": "embedded_mod.mbt",
    "command": ":embed -i $input -o $output --name moon_mod",
  }],
)
```

这将 `moon.mod` 的完整内容嵌入到 `embedded_mod.mbt` 中，用于提取应用版本号（`--version` 输出）。

### 参数解析

**`ParsedArgs`**：解析结果，包含 `raw: RawOptions` 和 `config_path: String?`。

**`parse_argv(Array[String])`** 定义了完整的 CLI 参数体系：

| 类别 | 参数 |
|------|------|
| Flag (12个) | `all`, `git-check`(negatable), `sign`, `update`(negatable), `push`(negatable), `yes`, `recursive`, `verify`(negatable), `ignore-scripts`, `quiet`, `print-commits`(negatable), `no-commit`, `no-tag` |
| Option (8个) | `preid`, `commit`, `tag`, `current-version`, `cwd`, `execute`, `release`, `configFilePath`/`config` |
| Positional (1个) | `files` (0..9999 个值) |

**特殊处理**：
- 第一个位置参数如果是有效的版本类型或版本号，自动识别为 `release`
- `--no-commit` → `TemplateSetting::Disabled`
- `--yes` → `confirm = false`（反转）
- `--no-git-check` → `no_git_check = true`（反转）
- `--no-verify` → `no_verify = true`（反转）

### 交互式界面（TUI）

采用 `@tui` + `@vnode` + `@render` 实现完整的全屏交互式终端界面：

**`prompt_release(ReleaseContext)`**：
- 启用终端 Raw Mode 捕获上下方向键（`Up`/`Down`）、回车、退格键和 `Ctrl+C`
- 支持 11 个预设选项（`patch`、`minor`、`major`、`next`、`conventional`、`prerelease`、`pre-patch`、`pre-minor`、`pre-major`、`as-is` 以及 `custom ...`）
- 选择 `custom ...` 时进入第二步，显示带光标的自定义版本号输入框
- 确认后动态清除渲染行，输出精美的确认结果摘要

**`confirm_plan(ReleasePlan)`**：
- 若 `plan.is_noop()` 为 true，提示版本未变并直接返回 `Ok(true)`
- 显示发布摘要（文件、commit 模板、tag 名称、push 状态）
- 启用 Raw Mode 单键确认 `Continue? (Y/n)`，支持 `y`/`n`/`Enter`/`Ctrl+C`

**`print_commits(Array[Commit])`**：
- 彩色格式化输出自上一个 Git tag 以来的提交记录
- 根据 commit 类型（`feat` 绿色、`fix` 黄色、`docs` 蓝色、`refactor` 青色、`breaking` 红色等）自动应用 ANSI 语法高亮和 scope 对齐

**`report_progress(ProgressEvent, Bool)`**：根据事件类型输出进度信息（quiet 模式下静默）。

---

## internal/config — 配置管理

**文件**：`config.mbt`  
**依赖**：model, `@semver`, `@fs`, `@json`

### 加载流程

```moonbit
///|
pub async fn load(cli: RawOptions, config_path: String?) -> Result[Options, AppError]
```

1. 确定配置文件路径（默认 `bump.config.json`，可通过 `--config` 指定）
2. 路径解析（相对于 `--cwd`）
3. 读取并解析 JSON 配置文件
   - 默认配置文件不存在时使用空选项（不报错）
   - 显式指定的配置文件不存在时报错
4. 合并：`config_file.merge(cli_args)`（CLI 参数优先）
5. 规范化：`normalize(merged)` → `Options`

### JSON 字段映射

| JSON (camelCase) | MoonBit (snake_case) |
|---|---|
| `noGitCheck` | `no_git_check` |
| `noVerify` | `no_verify` |
| `ignoreScripts` | `ignore_scripts` |
| `printCommits` | `print_commits` |
| `currentVersion` | `current_version` |

### 规范化逻辑

`normalize(RawOptions) → Result[Options, AppError]`：

- 解析 `release` 字符串为 `ReleaseSpec`
- 验证 `current_version` 为有效 SemVer
- 将 `commit`/`tag` 的 `TemplateSetting` 转换为 `CommitOptions?`/`TagOptions?`
- 为所有 `Bool` 字段设置默认值
- 当 `files` 显式指定时，强制 `recursive = false`

详见 [configuration.md](configuration.md)。

---

## internal/workflow — 流程编排

**文件**：`workflow.mbt`  
**依赖**：model, git, manifest, process

workflow 包是核心业务流程编排器，实现了 inspect → plan → execute 三阶段管道。

### inspect — 环境检查

```moonbit
///|
pub async fn inspect(options: Options) -> Result[ReleaseContext, AppError]
```

1. **Git 工作区检查**：除非 `all` 或 `no_git_check`，检查 `git status --porcelain`
2. **文件发现**：递归遍历或使用显式列表
3. **清单检查**：从第一个 `moon.mod` 读取版本号和生命周期脚本
4. **提交收集**：如果需要（`print_commits` 或 Conventional），获取上个标签以来的提交

### build_plan — 构建计划

```moonbit
///|
pub async fn build_plan(context: ReleaseContext, new_version: String) -> Result[ReleasePlan, AppError]
```

为每个文件构建 `FileEdit`（或标记为 skipped），格式化提交消息和标签名称。

### execute — 执行计划

```moonbit
///|
pub async fn execute(plan: ReleasePlan, emit?: (ProgressEvent) -> Unit) -> Result[Unit, AppError]
```

按顺序执行完整的发布流水线，每步发出进度事件，跟踪已完成步骤用于部分失败报告。

详见 [workflow.md](workflow.md)。

---

## internal/manifest — 清单文件操作

**文件**：`manifest.mbt`  
**依赖**：model, `@toml`, `@fs`, `@json`

### TOML 精确编辑

`read_version` 和 `update_version` 使用 TOML tokenizer（非 AST 解析）精确定位版本号字段，通过跟踪以下上下文确保只修改顶层 `version`：

- 行起始位置（`at_line_start`）
- 花括号/方括号/圆括号深度（`brace_depth`/`bracket_depth`/`paren_depth`）
- 是否在 table header 内（`in_table`）

这确保嵌套在 `import { ... }` 或 `options(...)` 中的 `version` 不会被误修改。

### 文本边界替换

`update_text_version` 对非 `moon.mod` 文件执行边界感知的版本号替换：
- 检查匹配位置前后字符是否为版本相邻字符（数字或点号）
- 避免部分匹配（如 `1.0.0` 不会匹配 `11.0.0` 中的 `1.0.0`）

### 文件发现

`discover_files`：
- **递归模式**：遍历目录树，排除 `.git`、`_build`、`.mooncakes`、`fixture`、`fixtures`
- **显式模式**：直接使用配置中的文件列表
- 结果排序并去重，验证所有文件存在

### 生命周期脚本解析

`read_scripts` 解析 `moon.mod` 中的 `options(scripts: { ... })` 块，提取 `preversion`、`version`、`postversion` 脚本。使用 TOML tokenizer 跟踪嵌套深度来正确解析。

---

## internal/git — Git 操作

**文件**：`git.mbt`  
**依赖**：model, process

### API 概览

| 函数 | 底层命令 | 说明 |
|------|----------|------|
| `check_clean(cwd)` | `git status --porcelain` | 工作区是否干净 |
| `get_commits(cwd)` | `git describe --tags` + `git log` | 获取提交记录 |
| `add(files, cwd)` | `git add -- files...` | 暂存文件 |
| `commit(opts, cwd, sign)` | `git commit -m msg [-S] [--no-verify]` | 创建提交 |
| `tag(opts, cwd, sign)` | `git tag -a\|-s name -m name` | 创建标签 |
| `push_commit(cwd)` | `git push` | 推送提交 |
| `push_tag(tag_name, cwd)` | `git push <remote> refs/tags/<name>:refs/tags/<name>` | 推送指定标签（自动解析 remote） |

### Conventional Commits 解析

`get_commits` 使用特殊分隔符格式获取提交记录：

```
git log [tag..HEAD] --format=%H%x1f%s%x1f%b%x1e
```

- `%x1f` (US) 作为字段分隔符（hash、subject、body）
- `%x1e` (RS) 作为记录分隔符

`parse_commit_record` 解析 Conventional Commit 格式：
- 提取 `type(scope)!: description`
- 检查 `BREAKING CHANGE:` / `BREAKING-CHANGE:` footer

---

## internal/process — 子进程管理

**文件**：`process.mbt`  
**依赖**：model, `@async_process`, `@env`

| 函数 | 说明 |
|------|------|
| `run_checked(command, args, cwd)` | 执行命令，非零退出码返回 `CommandFailed` 错误 |
| `capture(command, args, cwd)` | 执行命令并捕获 stdout/stderr，返回 `(exit_code, stdout, stderr)` |
| `run_shell_checked(script, cwd)` | 跨平台 shell 执行 |

**跨平台 shell 执行**：
- Windows (`OS == "Windows_NT"`)：`cmd /d /s /c script`
- Unix：`sh -c script`

---

## internal/platform — 平台抽象

**文件**：`platform.mbt`、`stub.c`

通过 C FFI 提供 Windows 控制台代码页管理：

```moonbit
///|
pub extern "c" fn get_console_output_cp() -> UInt = "bump_get_console_cp"

///|
pub extern "c" fn set_console_output_cp(cp: UInt) -> Unit = "bump_set_console_cp"
```

- Windows 上调用 `GetConsoleOutputCP()` / `SetConsoleOutputCP()`
- 其他平台为 no-op（返回 0 / 不执行任何操作）
- 在 `cmd/moon-bump` 中用于设置 UTF-8（65001）确保 emoji 和 Unicode 正确显示

---

> 📖 **更多信息**
> - 系统架构：[architecture.md](architecture.md)
> - 数据模型：[data-model.md](data-model.md)
> - 执行流程：[workflow.md](workflow.md)
