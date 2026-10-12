<p align="center"><img src="docs/assets/duck.png" alt="复制鸭" width="128"></p>

# 复制鸭 · CopyDuck

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

**复制一下，鸭来输入。**

一个简单的 macOS 菜单栏工具。按下自定义快捷键，通过系统输入法，把最新复制的文字写入当前输入框。

[三语介绍页](https://yuanruoyu515.github.io/CopyDuck/index.html) · [所有版本](https://github.com/yuanruoyu515/CopyDuck/releases)

## 下载

Apple Silicon · macOS 14 及以上 · 已在 macOS 27.0.1 实测

| 版本 | 下载 | 说明 |
| --- | --- | --- |
| 1.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.dmg) · [App 压缩包](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.app.zip) | [发布说明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.1) |
| 1.0 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.dmg) · [App 压缩包](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.app.zip) | [发布说明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.0) |

## 功能

- **你的快捷键**：默认 ⌃⌥V，也可以在设置中换成顺手的组合。
- **待在菜单栏**：不占 Dock；关掉设置窗口，仍在后台等你。
- **开机启动可选**：需要时开启，登录 Mac 后自动运行。
- **文字留在本机**：按快捷键时才读取剪贴板，不保存历史，不连接网络。

## 安装与使用

1. 下载 DMG，把“复制鸭”拖进“应用程序”。
2. 打开复制鸭，首次点击“安装输入组件”。
3. 看到“输入组件已就绪”后，复制文字，再到输入框按快捷键。

1.1 会自动启动已安装的组件。打开新版时，也会自动更新组件并保留快捷键。

默认快捷键: **⌃⌥V** (Control + Option + V).

## 工作原理

复制鸭可以添加到“简体中文”输入法列表。触发快捷键时，它读取剪贴板、临时切换输入源、提交文字，再恢复你原来的输入法。

`NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source`

## 使用范围与签名

支持纯文字，包括中文、英文、换行和表情；不支持图片、文件或富文本格式。目标输入框需要支持系统输入法，部分安全输入框或自定义控件可能限制输入。

在系统设置 → 键盘 → 文本输入 → 编辑 → ＋ → 简体中文中添加“复制鸭”，再重新打开应用。个别首次安装需要注销并重新登录。

目前提供本机签名版本，尚未使用 Developer ID 签名或 Apple 公证。在其他 Mac 上打开时，系统可能要求在“隐私与安全性”中确认。

从菜单栏选择“退出复制鸭”。卸载前关闭开机启动，在系统键盘设置移除输入法，再移走应用程序和 ~/Library/Input Methods/复制鸭.app。

## 版本记录

1.1 修复重复安装才能工作的问题，并调整菜单栏和输入法菜单里的鸭子图标；1.0 保留最初的功能版本。

Git 历史保留 v1.0 与 v1.1 标签；后续修改直接在 main 分支维护。发布流程见 [开发说明](DEVELOPMENT.md).

## 从源码构建

安装 Apple Command Line Tools 和 Python 3 后，在项目目录运行：

```sh
zsh build.sh
```

生成 build/复制鸭.app。正式构建不会包含测试触发入口。项目使用系统框架，无第三方运行依赖。

检查菜单图标在普通和 Retina 尺寸下是否居中：

```sh
zsh scripts/test_icons.sh
```

生成 App 压缩包和带拖拽布局的 DMG：

```sh
zsh scripts/package.sh
```
