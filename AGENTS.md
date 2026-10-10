# AGENTS

## Project overview

这是一个移动端“校园失物招领”服务。

## Agents session rule

Agent 需要将本轮对话做出的改动汇总为 Markdown 文档，存储在 docs/agents 目录下，供后继 Agent 查阅。

后继 Agent 首先阅读 docs/agents 的 basic-info.md，获取当前工作的总体状态，其次再阅读分文档。

每次会话只做一项任务，结束后向用户提示，并进行 Git commit。参见 [贡献指南](/CONTRIBUTING.md)。

务必遵守此 Commit 规范，对于提交记录中的违规 Commit，不要学习。

一个小写前缀 `<type>`，然后是一个简短的 `<subject>` 描述：

```
<type>: <subject>
```

只可使用前缀： `feat`、`fix`、`docs`、`style`、`test`、`chore`、`ci`。

## Commands

```bash
# Get deps
flutter pub get

# Static analysis
flutter analyze

# Full unit testing
flutter test

# Running debug version
flutter run

# Building release version of APK
flutter build apk --release
```

若上述命令执行时间过长，请停止继续执行并要求用户手动验证。
