# 贡献指南

首先，不论你是真人还是 Agent，衷心感谢你抽出时间为本项目做出贡献！

我们欢迎任何类型的贡献，不论是新功能、Bug 修复还是文档修订。这些贡献将有效帮助我们开发本项目。

## 开发之前

请确保你的仓库已经跟进上游最新更改。

GitHub 网页端提供了简单的 Sync 功能。不过，我们推荐使用 Git CLI 工具进行同步：

```bash
# 添加上游仓库
git remote add upstream https://github.com/rt265/102401215-102401119.git

# 验证 upstream
git remote -v

# 获取上游更改
git fetch upstream

# 合并上游更改到你的分支
git merge upstream/main
```

## 开始开发

### Quick Start

1. 安装 [Flutter](https://docs.flutter.cn/install/)
2. `flutter pub get` - 获取项目依赖
3. `flutter run` - 启动 Debug 版本

### Commit 规范

一个小写前缀 `<type>`，然后是一个简短的 `<subject>` 描述：

```
<type>: <subject>
```

只可使用前缀： `feat`、`fix`、`docs`、`style`、`test`、`chore`、`ci`。

如果你使用 VSCode，可以使用 [git-commit-plugin](https://marketplace.visualstudio.com/items?itemName=redjue.git-commit-plugin) 等插件辅助写作。

### 推送前检查

```bash
flutter analyze
flutter test
```

## Pull Request

满足以下条件后，可以合并到上游主分支：

1. 已经和上游最新版本同步；
2. 通过静态检查和所有测试用例。GitHub Action CI 也会检查；
3. 上游主要维护者通过。
