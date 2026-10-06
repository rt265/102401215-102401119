# AGENTS

## Project overview

这是一个移动端“校园失物招领”服务。

## Agents session rule

Agent 需要将本轮对话做出的改动汇总为 Markdown 文档，存储在 docs/agents 目录下，供后继 Agent 查阅。

后继 Agent 首先阅读 docs/agents 的 basic-info.md，获取当前工作的总体状态，其次再阅读分文档。

## Build and test commands

```bash
flutter pub get
flutter analyze
flutter test
```

若上述命令执行时间过长，请停止继续执行并要求用户手动验证。

## Testing instructions
