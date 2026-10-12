# 复制鸭

一个白底小鸭子图标的 macOS 菜单栏工具。按一次自定义快捷键，将最新剪贴板文字通过 macOS 输入法接口写入当前输入框，再恢复之前的输入法。

## 安装与使用

1. 打开 DMG，把“复制鸭”拖到“应用程序”。
2. 打开应用程序里的“复制鸭”，点击“安装输入组件”。它会安装到当前用户的 `~/Library/Input Methods/复制鸭.app`，无需管理员密码。
3. 看到“输入组件已就绪”后，复制一段文字，点一下目标输入框，再按快捷键。首次使用的默认快捷键为 **⌃⌥V**。
4. 点击菜单栏的小鸭子 →“设置”，可以更改快捷键和开机启动。关闭设置窗口后，应用继续运行；菜单栏的“退出复制鸭”才会结束运行。

系统键盘设置中，“复制鸭”归在简体中文输入法里。若系统没有自动启用，可在“系统设置 → 键盘 → 文本输入 → 编辑 → ＋ → 简体中文”中添加“复制鸭”，再重新打开应用；个别首次安装需要注销并重新登录。

当前版本支持纯文字，包括中文、英文、换行和表情。图片、文件和富文本格式不会通过输入法写入。应用只在快捷键触发时读取剪贴板，不保存剪贴板历史，不连接网络。

## 本机版本

- 版本：1.0
- 适用：Apple Silicon Mac；目标系统 macOS 14 及以上，已在本机 macOS 27.0.1 实测。
- 本版本为本机签名，未使用 Developer ID 签名或 Apple 公证；在其他 Mac 上安装时，系统可能要求在“隐私与安全性”中确认打开。
- 开机启动默认关闭，可在设置中自行开启。若 macOS 要求批准，点击应用提供的系统设置入口。

## 卸载

先在设置中关闭开机启动，再从菜单栏退出。到系统键盘设置移除“复制鸭”输入法，然后把“应用程序”里的复制鸭，以及 `~/Library/Input Methods/复制鸭.app` 移到废纸篓。

## 编译

安装 Apple Command Line Tools 后，在此目录运行 `zsh build.sh`，即可生成 `build/复制鸭.app`。项目使用系统的 AppKit、SwiftUI、InputMethodKit、Carbon 和 ServiceManagement，无第三方运行依赖。默认构建为正式版本；`--debug` 仅用于附带的输入测试，不用于分发。

## 实现

全局快捷键由 Carbon 注册；输入组件注册为简体中文输入源。触发时读取最新剪贴板、记录前台应用和原输入源，临时选择复制鸭，通过 `IMKTextInput.insertText` 提交文字，然后切回原输入源。请求只能提交一次，目标应用发生变化或连接超时会取消。应用以 `LSUIElement` 运行，开机启动使用 `SMAppService.mainApp`。

接口参考：[Apple InputMethodKit](https://developer.apple.com/documentation/inputmethodkit)、[Apple 登录启动接口](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)。
