# 版本记录 / 版本紀錄 / Changelog

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
