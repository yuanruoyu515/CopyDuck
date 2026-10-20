# 版本记录 / 版本紀錄 / Changelog

## 1.2.2 — 2026-10-20

**简体中文**

- 修复进程无法正确运行、重复启动造成大量资源占用的问题，以及设置窗口无法正常打开的问题。
- 主程序与输入法组件使用不同的应用身份，内嵌、安装和签名分别处理；保留原来的快捷键、模式及速度偏好。
- 主程序和组件分别防止重复启动；等设置窗口确认打开后再退出启动器，超时显示错误。
- 保留 1.2.1 的 Word 输入及资源清理改进。正式版构建编号 9，确保 build 8 beta 的组件也能升级。
- 已通过编译、签名及自动回归；macOS 26 的兼容性与资源占用仍待实际验证。

**繁體中文**

- 修復程序無法正確執行、重複啟動造成大量資源占用，以及設定視窗無法正常開啟的問題。
- 主程式與輸入法元件採用不同的應用程式身分，分別處理內嵌、安裝與簽署；保留原有快捷鍵、模式與速度偏好。
- 主程式與元件分別防止重複啟動；收到設定視窗開啟確認後才結束啟動器，逾時顯示錯誤。
- 保留 1.2.1 的 Word 輸入與資源清理改進。正式版組建編號 9，可升級 build 8 beta 元件。
- 已通過建置、簽署與自動回歸；macOS 26 的相容性及資源占用仍待實際驗證。

**English**

- Fix startup process failures and repeated launches that cause excessive resource usage, and Settings failing to open.
- Give the launcher and input-method component distinct bundle identities; embed, install and sign the component separately while retaining the original preferences domain.
- Enforce one instance per role and wait for Settings to acknowledge opening before exiting the launcher, with a visible timeout error.
- Retain the Word input and resource-cleanup improvements from 1.2.1. Stable build 9 upgrades the build 8 beta component.
- Build, signatures and automated regression checks passed. macOS 26 compatibility and resource usage still require desktop verification.

## 1.2.1 — 2026-10-19

**简体中文**

- 普通模式和模拟输入均改为等待输入源、输入连接稳定后再提交，避免在输入法激活回调中立即写入。
- 区分全局快捷键的转发事件与手动输入，防止触发动作误停本次请求。模拟输入遇到短暂的组件停用时，只允许原控制器及原客户端在有限时间内重连，已提交字符不重发。
- 取消任务时立即释放回调捕获对象，取消待执行任务；关闭设置窗口释放界面，共用一份小图标。文字按字素遍历，不预先拆成字符数组。
- 构建编号 7；维护者已试用本地测试版并确认无明显问题。自动回归覆盖 1,000 次长文本启动/取消及资源释放；通过构建与图标检查。

**繁體中文**

- 一般模式與模擬輸入皆改為等待輸入來源、輸入連線穩定後再提交，避免在輸入法啟用回呼中立即寫入。
- 區分全域快捷鍵的轉送事件與手動輸入，防止觸發動作誤停本次請求。模擬輸入遇到短暫的元件停用時，只允許原控制器及原用戶端在有限時間內重新連線，已提交字元不重送。
- 取消任務時立即釋放回呼捕獲物件，取消待執行任務；關閉設定視窗釋放介面，共用一份小圖示。文字依字素走訪，不預先拆成字元陣列。
- 組建編號 7；維護者已試用本機測試版並確認無明顯問題。自動回歸涵蓋 1,000 次長文本啟動/取消與資源釋放；通過建置與圖示檢查。

**English**

- Both modes wait for the input source and client to settle instead of inserting inside IMK activation callbacks.
- Distinguish forwarded shortcut events from manual input so the trigger does not cancel its own request. Simulated typing permits a bounded reconnection of the original controller and client after transient deactivation; submitted characters are never replayed.
- Cancellation drops callback captures immediately and cancels pending work. Closing Settings releases its view; reuse one small icon. Iterate text by grapheme without creating a character array.
- Build 7; the maintainer tested the local trial and reported no apparent issues. Automated regression covers 1,000 long-text starts/cancellations and resource release; build and icon checks pass.

## 1.2 — 2026-10-16

**简体中文**

- 设置窗口和菜单栏均可切换普通模式、模拟输入，并记住选择。
- 模拟输入逐字提交剪贴板纯文字，提供中速、快速、特别快三档（约每秒 5、10、20 字），标点和换行稍作停顿。
- 再次按快捷键、菜单中点击停止、手动打字或改变输入位置会中止；已输入的文字保留，并恢复原输入法。速度调整从下次输入生效。
- 保留完整中文、组合字符及表情；只在触发时读取最新剪贴板。构建编号为 5；维护者已完成本机试用。

**繁體中文**

- 設定視窗與選單列皆可切換一般模式、模擬輸入，並記住選擇。
- 模擬輸入逐字提交剪貼簿純文字，提供中速、快速、特別快三段（約每秒 5、10、20 字），標點與換行稍作停頓。
- 再次按快捷鍵、在選單中點選停止、手動打字或改變輸入位置會中止；保留已輸入的文字，並恢復原輸入法。速度調整從下次輸入生效。
- 保留完整中文、組合字元與表情；只在觸發時讀取最新剪貼簿。組建編號為 5；維護者已完成本機試用。

**English**

- Switch Normal / Simulated Typing in Settings or the menu bar; remember mode and speed.
- Type clipboard text one grapheme at a time at about 5, 10 or 20 characters per second, with small timing variations and punctuation/newline pauses.
- Press the shortcut again, choose Stop, type manually or change input focus to cancel. Keep text already entered and restore the previous input method. Speed changes apply to the next request.
- Preserve Chinese, combining characters and emoji. Read the latest clipboard only when triggered. Build 5; the maintainer has completed local testing.

## 1.1 — 2026-10-12

**简体中文**

- 已安装的输入组件现在会在打开应用时自动启动，无需每次点击安装。
- 打开新版自动更新组件，保留快捷键和登录启动设置。
- 菜单栏及输入法选单图标按实际轮廓居中，提供普通及 Retina 分辨率。
- 更新时刷新复制鸭输入源，避免继续显示旧图标。

**繁體中文**

- 已安裝的輸入元件會在開啟應用程式時自動啟動，不必每次點選安裝。
- 開啟新版自動更新元件，保留快捷鍵與登入時啟動設定。
- 選單列與輸入法選單圖示依實際輪廓置中，提供一般與 Retina 解析度。
- 更新時重新整理複製鴨輸入來源，避免繼續顯示舊圖示。

**English**

- Automatically start the installed input component when opening the app.
- Update older components automatically while preserving shortcut and login settings.
- Center menu bar and input source icons at standard and Retina resolutions.
- Refresh CopyDuck's input sources during updates to avoid stale menu icons.

## 1.0 — 2026-10-11

**简体中文**：初始版本。自定义全局快捷键，通过简体中文输入组件提交最新剪贴板纯文字，输入后恢复原输入法。菜单栏常驻、可选开机启动、关闭设置窗口后继续运行。

**繁體中文**：初始版本。自訂全域快捷鍵，透過簡體中文輸入元件提交最新剪貼簿純文字，輸入後恢復原輸入法。常駐選單列、可選登入時啟動、關閉設定視窗後繼續執行。

**English**: Initial release. A customizable global shortcut commits the latest clipboard text through a Simplified Chinese input component, then restores the previous input method. Includes a menu bar app, optional launch at login and background operation after closing Settings.
