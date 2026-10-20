# 开发与发布

当前维护分支是 `main`。`v1.0` 保存原始功能版本，`v1.1` 保存组件自动启动和菜单图标修复版本，`v1.2` 增加逐字模拟输入与速度选择，`v1.2.1` 改善 Word 输入时序并强化资源清理。每个标签对应源码及独立的 GitHub Release。

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

## 1.2.1 输入稳定与资源清理验证

正式版构建编号 7（本地 1.2.1-beta.1 为 6）。维护者试用本地测试版后反馈无明显问题，并确认发布正式更新。正式版递增构建编号，确保已安装测试版也能自动更新。

`zsh scripts/test_typing.sh` 现在还检查输入连接延迟就绪、两种模式的调度、未提交字符的有限重试、旧回调与新请求隔离、同步取消、真实 Dispatch 回调捕获对象的立即释放，以及 1,000 次长文本启动/取消后的任务清理。快捷键测试使用实际 `Shortcut` 实现，检查转发事件匹配、手动输入、不同修饰键与 Caps Lock/Fn。

当前测试证明调度与对象持有关系的清理，不等同于完整应用的泄漏扫描或实际内存峰值测量。关闭设置会清除内容视图并移除窗口引用；后台输入组件仍常驻，系统的 SwiftUI/AppKit 缓存及分配器可能保留部分已申请内存。

自动化的 Word 桌面测试连接曾超时，未取得现场复现记录；维护者的试用反馈不代表所有目标应用与场景均已验证。后续回归应分别在普通模式、三档模拟输入下检查：刚打开 Word 后首次触发、连续触发、长中文段落、选区替换、输入后切换应用再返回。必须确认第一次按键即完整输入，且没有多余快捷键字符；模拟输入不在第一字后误停，也不重复已提交的字。再次按快捷键仍应停止；手动输入、移动光标、点击另一输入框、关闭文档、更换控制器或客户端均不能把后续文字写入新位置。组件短暂停用仅允许原控制器与原客户端在 0.6 秒内重新就绪。

检查设置窗口反复开关后能重新创建界面，关闭后菜单栏及快捷键仍有效。使用活动监视器或 Instruments 比较闲置、反复开关设置、长文本输入/取消后的内存趋势，勿把一次 RSS 数值下降或系统缓存保留误当成泄漏结论。

## 更新版本

1. 同步修改 `Resources/Info.plist` 和 `Resources/InputMethodInfo.plist` 的 `CFBundleShortVersionString`，并递增 `CFBundleVersion`。两个 bundle 的版本必须一致；输入组件根据构建编号判断是否自动更新。
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

### 1.2.2-beta.1 启动修复（build 8）

参考使用者提供并确认可用的 `复制鸭-source-build7.zip`，将启动器与输入法组件拆分：外层为 `com.copyduck.app`，内嵌及安装后的输入组件仍为 `com.copyduck.inputmethod.CopyDuck`。外层不再带输入法服务器注册信息；安装时只复制内嵌组件。两者共用原来的偏好域，保留快捷键、模式和速度。角色由 bundle ID 判断，不依赖可能被 App Translocation 改变的运行路径。构建时先签署组件，再签署外层应用。

启动器及组件分别持有单实例锁；不能创建锁时显示错误并退出，不继续创建无锁实例。启动器等到组件确认已打开设置窗口后才退出；通知每 0.25 秒重试，最多等候 10 秒，超时显示可重试的错误界面。使用者参考包只用于提取启动与打包修法；1.2.1 的 Word 输入调度、取消与资源清理代码继续保留。

```sh
zsh scripts/test_startup.sh
```

自动测试检查双 bundle 身份及版本一致、24 个并发组件争抢同一锁、启动器去重、两种角色独立运行、退出后重新获取锁，以及锁创建失败。该脚本也编译下面的桌面集成测试。构建及自动测试不能替代故障机器的实际启动验证；此修复先提供 beta，不替换既有正式 Release。

在真实 Mac 桌面会话中打开新版并完成组件升级后执行：

```sh
build/StartupIntegration burst /Applications/复制鸭.app
build/StartupIntegration check 8
```

`burst` 连续发出 12 次启动请求，要求最终只保留一个组件、没有遗留启动器，并收到设置窗口确认。另需手动检查全新安装、从旧版升级、退出后重开、关闭或最小化设置后重开，以及快捷键、模式、速度和开机启动设置是否保留。无需安装的源码检查不代表这些桌面场景已通过。

```sh
swiftc -parse-as-library -module-cache-path build/module-cache \
  Tests/StartupIntegration.swift -o build/StartupIntegration
build/StartupIntegration check <build-number>
```

测试前先正常打开安装后的应用。`check` 验证只有一个后台组件、无 Dock 图标、输入源已启用。`quit` 会正常退出本机已安装的组件，适合验证重新打开后无需点击安装。

## 界面内容

简体、繁体、英文文案统一维护在 `website/content.json`，避免三语说明与产品行为不一致。应用本身当前使用简体中文界面；介绍页的三种语言不会改变应用界面语言。
