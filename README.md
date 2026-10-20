<p align="center"><img src="docs/assets/duck.png" alt="复制鸭" width="128"></p>

# 复制鸭 · CopyDuck

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

> [!WARNING]
> **兼容性与资源占用提醒**
> 目前仅在 macOS 27.0.1 上验证，不保证 macOS 27 以下版本可用。已有用户反馈：修复前版本在 macOS 26 上出现内存与 CPU 占用异常飙升；新版在该系统上的表现仍待验证。如遇异常，请立即退出复制鸭；无法退出时，可在活动监视器中结束 CopyDuck 进程。

**复制一下，鸭来输入。**

💢 输入框不让粘贴，或者会区分粘贴与正常输入，让你只能重新手打一遍？

🐤 复制鸭（CopyDuck）是一款轻量的 macOS 菜单栏工具：按下快捷键，就能通过系统输入法，将剪贴板中的纯文字直接输入当前输入框。它适用于部分禁用粘贴、拦截粘贴快捷键，但仍支持系统输入法的网页和应用，减少重复录入长段文字的麻烦。支持中文、英文、换行和表情，文字处理全程在本机完成，不上传内容，也不保存剪贴板历史。

## 💦 灵感来源

作者在上 AP CSA 课时赶不完作业，偏偏 Albert 又被设置成不能粘贴，只好反复修改输入法的快捷输入词，把文字一点点塞进去……于是，就有了复制鸭。

[三语介绍页](https://yuanruoyu515.github.io/CopyDuck/index.html) · [所有版本](https://github.com/yuanruoyu515/CopyDuck/releases)

## 下载

Apple Silicon · 构建最低版本 macOS 14 · 仅在 macOS 27.0.1 上验证

| 版本 | 下载 | 说明 |
| --- | --- | --- |
| 1.2.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2.1/CopyDuck-1.2.1-arm64.dmg) · [App 压缩包](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2.1/CopyDuck-1.2.1-arm64.app.zip) | [发布说明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.2.1) |
| 1.2 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2/CopyDuck-1.2-arm64.dmg) · [App 压缩包](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.2/CopyDuck-1.2-arm64.app.zip) | [发布说明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.2) |
| 1.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.dmg) · [App 压缩包](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.app.zip) | [发布说明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.1) |
| 1.0 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.dmg) · [App 压缩包](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.app.zip) | [发布说明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.0) |

## 功能

- **你的快捷键**：默认 ⌃⌥V，也可以在设置中换成顺手的组合。
- **待在菜单栏**：不占 Dock；关掉设置窗口，仍在后台等你。
- **开机启动可选**：需要时开启，登录 Mac 后自动运行。
- **文字留在本机**：按快捷键时才读取剪贴板，不保存历史，不连接网络。
- **模拟输入**：在设置或菜单栏切换普通模式／模拟输入。中速、快速、特别快约为每秒 5、10、20 字，标点和换行稍作停顿。模式和速度会记住；速度调整从下次输入生效。再次按快捷键、手动打字或切换输入位置可停止，已输入的文字会保留。
- **输入稳定与资源清理**：改善 Word 首次触发和模拟输入误停。关闭设置时释放界面；输入结束或取消后清理文字引用、回调和定时任务。

## 真实界面，轻巧直观。

设置窗口和菜单栏截图由维护者试用 1.2-beta.1 时提供，展示 1.2 新增功能。界面为简体中文；⌥D 是自定义快捷键，默认是 ⌃⌥V。

### 设置窗口

<img src="docs/assets/settings.png" alt="设置窗口" width="560">

在设置中切换输入模式，选择中速、快速或特别快，并调整快捷键和开机启动。

### 系统输入法列表

<img src="docs/assets/input-sources.png" alt="系统输入法列表" width="560">

复制鸭作为系统输入法出现在已安装列表中。

### 菜单栏菜单

<img src="docs/assets/menu-bar.png" alt="菜单栏菜单" width="360">

点开菜单栏小鸭子，即可切换普通模式／模拟输入，并在子菜单选择三档速度。

## 安装与使用

1. 下载 DMG，把“复制鸭”拖进“应用程序”。
2. 打开复制鸭，首次点击“安装输入组件”。
3. 看到“输入组件已就绪”后，复制文字，再到输入框按快捷键。

打开新版会自动更新并启动输入组件，保留原快捷键和开机启动设置。

默认快捷键: **⌃⌥V** (Control + Option + V).

## 工作原理

复制鸭可以添加到“简体中文”输入法列表。触发快捷键时，它读取最新剪贴板、临时切换输入源，按所选模式一次写入整段或逐字输入，再恢复你原来的输入法。输入途中复制其他文字不会改变本次内容。

`NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source`

## 使用范围与签名

支持纯文字，包括中文、英文、换行和表情；不支持图片、文件或富文本格式。目标输入框需要支持系统输入法，部分安全输入框或自定义控件可能限制输入。

在系统设置 → 键盘 → 文本输入 → 编辑 → ＋ → 简体中文中添加“复制鸭”，再重新打开应用。个别首次安装需要注销并重新登录。

目前提供本机签名版本，尚未使用 Developer ID 签名或 Apple 公证。在其他 Mac 上打开时，系统可能要求在“隐私与安全性”中确认。

从菜单栏选择“退出复制鸭”。卸载前关闭开机启动，在系统键盘设置移除输入法，再移走应用程序和 ~/Library/Input Methods/复制鸭.app。

## 版本记录

1.2.1 改善 Word 首次触发和输入误停，强化取消任务与关闭设置时的内存清理。1.2 增加普通模式／模拟输入切换和三档打字速度；1.1 修复组件自动启动并调整图标；1.0 保留最初的功能版本。

Git 历史保留 v1.0、v1.1、v1.2 与 v1.2.1 标签；后续修改在 main 分支维护。发布流程见 [开发说明](DEVELOPMENT.md).

## 从源码构建

安装 Apple Command Line Tools 和 Python 3 后，在项目目录运行：

```sh
zsh build.sh
```

生成 build/复制鸭.app。正式构建不会包含测试触发入口。项目使用系统框架，无第三方运行依赖。

验证模拟输入的文字、速度与停止逻辑，并检查普通和 Retina 尺寸下的图标居中：

```sh
zsh scripts/test_typing.sh
zsh scripts/test_icons.sh
```

生成 App 压缩包和带拖拽布局的 DMG：

```sh
zsh scripts/package.sh
```
