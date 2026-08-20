# 错误处理文档

本文档详细描述 `moon-bump` 的错误处理机制，包括错误模型、传播模式和恢复指南。

## 1. 错误模型

moon-bump 使用单一的 `AppError` 枚举作为统一错误类型，定义在 `internal/model/error.mbt` 中：

```moonbit
///|
pub(all) enum AppError {
  InvalidArgument(String)
  Config(String)
  Manifest(String)
  Io(String)
  Git(String)
  CommandFailed(String, Int)
  Partial(String)
  Aborted
}
```

所有可能失败的函数统一返回 `Result[T, AppError]`，确保错误处理的一致性。

## 2. 错误变体详解

### InvalidArgument(String) — 无效参数

**触发场景**：
- CLI 参数解析失败
- 无效的版本类型字符串（如 `"foobar"`）
- 无效的版本号格式
- 尝试计算无法递增的版本号

**消息格式**：`"Invalid argument: {message}"`

**示例**：
```
Error: Invalid argument: invalid release or version: foobar
Error: Invalid argument: cannot increment 1.0.0 as prerelease
Error: Invalid argument: invalid current version: not-a-version
```

---

### Config(String) — 配置错误

**触发场景**：
- 显式指定的配置文件不存在
- 配置文件 JSON 解析失败
- 配置文件不是 JSON 对象
- 配置字段类型不正确

**消息格式**：`"Configuration error: {message}"`

**示例**：
```
Error: Configuration error: configuration file not found: `bump.config.json`
Error: Configuration error: failed to parse `bump.config.json`: ...
Error: Configuration error: `bump.config.json` must contain a JSON object
Error: Configuration error: field `release` must be a string
Error: Configuration error: field `files` must be an array of strings
```

---

### Manifest(String) — 清单文件错误

**触发场景**：
- `moon.mod` 中找不到顶层 `version` 字段
- 存在重复的顶层 `version` 字段
- `version` 字段格式不正确（非引号字符串）
- 没有文件匹配发布配置
- 当前版本号无效
- 未选择 `moon.mod` 且未提供 `--current-version`

**消息格式**：`"Manifest error: {message}"`

**示例**：
```
Error: Manifest error: top-level `version` field not found
Error: Manifest error: duplicate top-level `version` fields
Error: Manifest error: `version` must be a quoted string
Error: Manifest error: no files matched the release configuration
Error: Manifest error: no moon.mod was selected and --current-version was not provided
Error: Manifest error: invalid current version: abc
Error: Manifest error: `moon.mod`: script `preversion` must be a quoted string
```

---

### Io(String) — I/O 错误

**触发场景**：
- 文件读取失败
- 文件写入失败
- 目录扫描失败
- 子进程启动失败

**消息格式**：`"I/O error: {message}"`

**示例**：
```
Error: I/O error: failed to read `moon.mod`: FileNotFound
Error: I/O error: failed to write `moon.mod`: PermissionDenied
Error: I/O error: failed to scan `.`: ...
Error: I/O error: file not found: `README.md`
Error: I/O error: failed to start [cwd=.] git push: ...
```

---

### Git(String) — Git 操作错误

**触发场景**：
- 工作区不干净
- Git 命令执行失败（通过 stderr 获取详情）
- 读取提交记录失败

**消息格式**：`"Git error: {message}"`

**示例**：
```
Error: Git error: working tree is not clean
Error: Git error: failed to inspect working tree: not a git repository
Error: Git error: failed to read commits: ...
```

---

### CommandFailed(String, Int) — 命令执行失败

**触发场景**：
- 任何子进程以非零退出码退出
- 包括 Git 命令、`moon update`、用户自定义命令、生命周期脚本

**消息格式**：`"Command failed with exit code {code}: {command}"`

**示例**：
```
Error: Command failed with exit code 128: [cwd=.] git "push"
Error: Command failed with exit code 1: [cwd=.] moon "update"
Error: Command failed with exit code 1: [cwd=.] sh "-c" "moon build --release"
```

命令字符串包含 `[cwd=路径]` 前缀，帮助定位执行环境。

---

### Partial(String) — 部分完成

**触发场景**：
- 在 `execute()` 阶段中某个步骤失败，但之前的步骤已经完成

**消息格式**：
```
"Release partially completed: failed during {step}; completed local steps: {step1}, {step2}, ...; cause: {原始错误消息}"
```

**示例**：
```
Error: Release partially completed: failed during git push; completed local steps: preversion, updated moon.mod, git add, git commit, git tag; cause: Command failed with exit code 128: [cwd=.] git "push"
```

> ⚠️ **重要**：`Partial` 是最关键的错误类型。部分完成的发布可能导致仓库处于不一致状态（例如本地已提交和打标签，但未推送到远程）。用户需要根据已完成步骤信息手动完成剩余操作或回滚。

---

### Aborted — 用户取消

**触发场景**：
- 用户在确认提示时输入 `n` 或非确认值

**消息格式**：`"Aborted by user."`

**示例**：
```
Error: Aborted by user.
```

## 3. 错误传播模式

moon-bump 使用 MoonBit 的 `Result` 类型，配合 match + early return 模式统一传播错误：

```moonbit
///|
let value = match some_operation() {
  Ok(value) => value
  Err(error) => return Err(error)
}
```

这个模式在整个代码库中一致使用。所有 `async` 函数同样通过 `Result` 传播错误。

**错误从底层传播到顶层的路径**：

```
process.run_checked()        → CommandFailed
  ↓ 传播
git.push_commit()            → Git / CommandFailed
  ↓ 传播
workflow.execute()           → Partial (包装原始错误)
  ↓ 传播
cmd/moon-bump/run_app()      → 任何 AppError
  ↓ 捕获
cmd/moon-bump/main()         → 打印消息并退出
```

## 4. 部分失败处理 (Partial Failure)

`execute()` 阶段执行的是可能不可逆的操作（如文件写入、Git 提交）。为了帮助用户在失败时恢复，它跟踪每一步的完成状态：

```moonbit
///|
let completed = []

// 步骤 1：preversion 脚本
match run_script("preversion", ...) {
  Ok(_) => ()  // completed 在 run_script 内部追加
  Err(error) => return Err(error)
}

// 步骤 2：文件更新
for edit in plan.edits {
  match write_edit(...) {
    Ok(_) => {
      completed.push("updated {edit.path}")
      emit(FileUpdated(edit.path))
    }
    Err(error) => return Err(partial_failure("file update", error, completed))
  }
}

// ... 后续步骤类似 ...
```

`partial_failure()` 构造包含已完成步骤信息的 `Partial` 错误：

```moonbit
///|
fn partial_failure(step: String, error: AppError, completed: Array[String]) -> AppError {
  Partial(
    "failed during {step}; completed local steps: {completed_text(completed)}; cause: {error.message()}"
  )
}
```

## 5. 顶层错误处理

在 `cmd/moon-bump/main.mbt` 中，所有错误统一处理并支持异步任务取消捕获：

```moonbit
///|
let raw_result : Result[Unit, @model.AppError] = run_app() catch {
  _ if @async.is_being_cancelled() => Err(Aborted)
  error => raise error
}
let result : Result[Unit, @model.AppError] = if @async.is_being_cancelled() {
  Err(Aborted)
} else {
  raw_result
}

if old_cp != 0U {
  @platform.set_console_output_cp(old_cp)
}
match result {
  Ok(_) => ()
  Err(Aborted) => {
    println("Error: Aborted.")
    @sys.exit(1)
  }
  Err(error) => {
    println("Error: \{error.message()}")
    @sys.exit(1)
  }
}
```

- 捕获异步取消信号（Ctrl+C 等）转换为 `Aborted`
- 错误信息以 `Error:` 前缀打印到 stdout
- 退出码统一为 `1`
- Windows 代码页在错误处理前即完成恢复（确保终端状态正确）

## 6. 错误恢复指南

| 错误类型 | 恢复方法 |
|----------|----------|
| `InvalidArgument` | 检查 CLI 参数格式、版本号格式，运行 `moon-bump --help` |
| `Config` | 检查 `bump.config.json` 的 JSON 语法和字段类型 |
| `Manifest` | 确认 `moon.mod` 存在且包含有效的顶层 `version = "x.y.z"` 字段 |
| `Io` | 检查文件权限、路径是否正确、磁盘空间 |
| `Git` | 确认在 Git 仓库中；工作区不干净时使用 `--no-git-check` 或先提交/暂存 |
| `CommandFailed` | 检查命令是否可用（Git、moon 等），查看命令输出定位问题 |
| `Partial` | **最关键**——查看已完成步骤列表，手动完成剩余操作或回滚已完成步骤 |
| `Aborted` | 重新运行并确认，或使用 `--yes` 跳过确认 |

### Partial 错误的恢复步骤

当遇到 `Partial` 错误时，根据已完成步骤决定恢复方案：

| 已完成到 | 恢复方案 |
|----------|----------|
| 仅文件更新 | 手动回滚文件（`git checkout -- moon.mod`） |
| git commit | 回滚提交（`git reset HEAD~1`）或继续手动打标签推送 |
| git tag | 继续手动推送标签（`git push <remote> refs/tags/<name>:refs/tags/<name>`） |
| git push (commit) | 继续推送指定标签（`git push <remote> refs/tags/<name>:refs/tags/<name>`） |

---

> 📖 **更多信息**
> - 数据模型：[data-model.md](data-model.md)
> - 执行流程：[workflow.md](workflow.md)
