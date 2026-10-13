<p align="center"><img src="docs/assets/duck.png" alt="複製鴨" width="128"></p>

# 複製鴨 · CopyDuck

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

**複製一下，鴨來輸入。**

一個簡單的 macOS 選單列工具。按下自訂快捷鍵，透過系統輸入法，把最新複製的文字寫入目前的輸入框。

[三語介紹頁](https://yuanruoyu515.github.io/CopyDuck/zh-Hant/index.html) · [所有版本](https://github.com/yuanruoyu515/CopyDuck/releases)

## 下載

Apple Silicon · macOS 14 以上 · 已在 macOS 27.0.1 實測

| 版本 | 下載 | 說明 |
| --- | --- | --- |
| 1.1 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.dmg) · [App 壓縮檔](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.1/CopyDuck-1.1-arm64.app.zip) | [版本說明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.1) |
| 1.0 | [DMG](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.dmg) · [App 壓縮檔](https://github.com/yuanruoyu515/CopyDuck/releases/download/v1.0/CopyDuck-1.0-arm64.app.zip) | [版本說明](https://github.com/yuanruoyu515/CopyDuck/releases/tag/v1.0) |

## 功能

- **你的快捷鍵**：預設 ⌃⌥V，也可以在設定中換成順手的組合。
- **待在選單列**：不占 Dock；關閉設定視窗，仍在背景等你。
- **登入時啟動可選**：需要時開啟，登入 Mac 後自動執行。
- **文字留在本機**：按快捷鍵時才讀取剪貼簿，不儲存歷史，不連接網路。

## 真實介面，輕巧直觀。

截圖使用簡體中文介面；⌥D 為自訂快捷鍵，預設為 ⌃⌥V。

### 設定視窗

<img src="docs/assets/settings.png" alt="設定視窗" width="560">

調整快捷鍵與登入時啟動；輸入元件已就緒。

### 系統輸入法列表

<img src="docs/assets/input-sources.png" alt="系統輸入法列表" width="560">

複製鴨以系統輸入法顯示於已安裝列表中。

### 選單列選單

<img src="docs/assets/menu-bar.png" alt="選單列選單" width="360">

從選單列輸入文字、開啟設定或結束應用程式。

## 安裝與使用

1. 下載 DMG，把「复制鸭」拖進「應用程式」。
2. 開啟複製鴨，首次點選「安装输入组件」。
3. 看到「输入组件已就绪」後，複製文字，再到輸入框按快捷鍵。

1.1 會自動啟動已安裝的元件。開啟新版時，也會自動更新元件並保留快捷鍵。

預設快捷鍵: **⌃⌥V** (Control + Option + V).

## 運作原理

複製鴨可以加入「簡體中文」輸入法列表。觸發快捷鍵時，它讀取剪貼簿、暫時切換輸入來源、提交文字，再恢復原本的輸入法。

`NSPasteboard → TISSelectInputSource → IMKTextInput.insertText → restore previous input source`

## 使用範圍與簽署

支援純文字，包括中文、英文、換行和表情；不支援圖片、檔案或富文字格式。目標輸入框須支援系統輸入法，部分安全輸入框或自訂控制項可能限制輸入。

在系統設定 → 鍵盤 → 文字輸入 → 編輯 → ＋ → 簡體中文中加入「复制鸭」，再重新開啟應用程式。個別首次安裝需要登出並重新登入。

目前提供本機簽署版本，尚未使用 Developer ID 簽署或 Apple 公證。在其他 Mac 上開啟時，系統可能要求在「隱私權與安全性」中確認。

從選單列選擇「退出复制鸭」。移除前關閉登入時啟動，在系統鍵盤設定移除輸入法，再移走應用程式與 ~/Library/Input Methods/复制鸭.app。

## 版本紀錄

1.1 修復每次需重新安裝才會運作的問題，並調整選單列與輸入法選單中的鴨子圖示；1.0 保留最初的功能版本。

Git 歷史保留 v1.0 與 v1.1 標籤；後續修改直接在 main 分支維護。發佈流程請見 [開發說明](DEVELOPMENT.md).

## 從原始碼建置

安裝 Apple Command Line Tools 與 Python 3 後，在專案目錄執行：

```sh
zsh build.sh
```

產生 build/复制鸭.app。正式建置不包含測試觸發入口。專案使用系統框架，沒有第三方執行相依套件。

檢查選單圖示在一般與 Retina 尺寸下是否置中：

```sh
zsh scripts/test_icons.sh
```

產生 App 壓縮檔與可拖曳安裝的 DMG：

```sh
zsh scripts/package.sh
```
