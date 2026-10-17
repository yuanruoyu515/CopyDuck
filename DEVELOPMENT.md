# 开发与发布

当前维护分支是 `main`。`v1.0` 保存原始功能版本，`v1.1` 保存组件自动启动和菜单图标修复版本，`v1.2` 增加逐字模拟输入与速度选择。每个标签对应源码及独立的 GitHub Release。

## 目录

- `Sources/`：Swift 应用、输入法服务器、快捷键、设置和图标绘制。
- `Resources/Info.plist`：应用版本、输入法注册信息和图标资源名。
- `Tests/`：图标居中检查、已安装组件检查和手动输入测试。
- `website/`：三语介绍内容与样式；`docs/` 是 GitHub Pages 发布目录。
- `scripts/`：介绍页生成、图标检查、App 与 DMG 打包。

源码可公开查看，项目当前尚未指定开源许可证。

## 本机构建

需要 Apple Silicon Mac、Apple Command Line Tools、Python 3。已在 macOS 27.0.1 上验证；构建目标为 macOS 14 及以上。

```sh
zsh build.sh
zsh scripts/test_icons.sh
```

正式版本不包含分布式通知测试触发入口。`zsh build.sh --debug` 只用于输入测试，不用于发布。

`Tests/InputProbe.swift` 提供拒绝普通粘贴的原生测试输入框；`Tests/no-paste.html` 提供网页测试输入框。测试文字包含中文、英文、换行、表情、选区替换和长文本。输入框是否接受输入仍由目标应用决定。

## 1.2 模拟输入验证

1.2 正式版构建编号为 5。维护者已试用 1.2-beta.1 并确认基本功能；此记录不代表所有目标应用、输入框和取消场景均已验证。

```sh
zsh scripts/test_typing.sh
```

该测试验证逐字调度、Unicode 字素完整性、选区替换、取消与重试、焦点校验拒绝写入、同步取消、空内容和长文本、三档速度及偏好设置回退。它不替代已安装输入组件的实际桌面测试。

安装后，在 `Tests/InputProbe.swift` 的拒绝粘贴输入框和 `Tests/no-paste.html` 中分别验证普通模式、三档模拟速度。每次触发读取最新剪贴板；输入途中改变剪贴板不应改变本次内容。检查中文、多行、制表符、组合表情与选区替换；再检查超过两秒的输入不会超时，重复按快捷键、手动打字、移动光标、同应用切换输入框、切换应用、切换输入法、关闭目标窗口及退出复制鸭均能停止。停止后不应继续输入；重新触发不得混入旧请求。输入完成或取消后应恢复原输入法；用户自行切换的输入法不得被覆盖。

设置与菜单栏的选中状态应同步；重启后保留模式和速度。速度修改从下一次请求生效。打开新版会沿用现有安装流程更新组件，保留原快捷键和开机启动设置。

## 更新版本

1. 修改 `CFBundleShortVersionString`，并递增 `CFBundleVersion`。输入组件根据构建编号判断是否自动更新。
2. 更新 `website/content.json` 中的版本、下载信息与三语发布说明；同时更新 `releases` 版本列表；生成器统一读取该列表与当前版本。
3. 运行 `python3 scripts/build_site.py`，同步三语 README 与介绍页面。
4. 构建、检查图标，然后生成安装包。App 只在用户主动按快捷键时读取剪贴板。

## 打包

```sh
zsh scripts/package.sh
```

首次打包会在忽略的 `.venv/` 中安装 `ds-store`、`mac-alias`，仅用于设置 DMG 的背景与图标位置。App 运行无第三方依赖。正式产物写入忽略的 `.release/<版本>/`：

- `CopyDuck-<版本>-arm64.dmg`
- `CopyDuck-<版本>-arm64.app.zip`
- `SHA256SUMS.txt`

当前使用本机签名，尚未使用 Developer ID 或 Apple 公证。不能把这个构建标为已公证版本。

## 发布到 GitHub

先确认构建版本与标签一致，提交源码，再给该提交添加标签并推送：

```sh
git add .
git commit -m "Release CopyDuck <version>"
git tag -a "v<version>" -m "CopyDuck <version>"
git push origin main --tags
gh release create "v<version>" .release/<version>/CopyDuck-* .release/<version>/SHA256SUMS.txt \
  --verify-tag --title "CopyDuck <version>" --notes-file <release-notes.md>
```

把版本占位符换成实际版本。发布前不要重新打包已经发布的历史标签，也不要移动旧标签；版本修复应创建新版本。

介绍页由 GitHub Pages 发布 `main` 分支下的 `/docs`。更新并推送该目录后，页面会自动重新部署。

## 手动验证启动

```sh
swiftc -parse-as-library -module-cache-path build/module-cache \
  Tests/StartupIntegration.swift -o build/StartupIntegration
build/StartupIntegration check <build-number>
```

测试前先正常打开安装后的应用。`check` 验证只有一个后台组件、无 Dock 图标、输入源已启用。`quit` 会正常退出本机已安装的组件，适合验证重新打开后无需点击安装。

## 界面内容

简体、繁体、英文文案统一维护在 `website/content.json`，避免三语说明与产品行为不一致。应用本身当前使用简体中文界面；介绍页的三种语言不会改变应用界面语言。
