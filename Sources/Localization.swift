import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplified = "zh-Hans"
    case traditional = "zh-Hant"
    case english = "en"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .simplified: return "简体中文"
        case .traditional: return "繁體中文"
        case .english: return "English"
        }
    }

    static func load(from defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .simplified
    }
}

enum L10n {
    enum CountEvent { case inserted, simulated, switchedApp, movedFocus, fieldClosed, stopped }

    static var current: AppLanguage {
        AppLanguage.load(from: UserDefaults(suiteName: "com.copyduck.inputmethod.CopyDuck") ?? .standard)
    }

    // Simplified Chinese is the key and fallback for existing users.
    private static let translations: [String: (traditional: String, english: String)] = [
        "复制鸭": ("複製鴨", "CopyDuck"),
        "复制一下，鸭来输入。": ("複製一下，鴨來輸入。", "Copy once. Let the duck type."),
        "输入组件已就绪": ("輸入元件已就緒", "Input method is ready"),
        "完成一次设置，就可以用了": ("完成一次設定，就可以使用", "Finish setup to get started"),
        "纯文字 · 本机处理": ("純文字 · 本機處理", "Plain text · On-device"),
        "输入快捷键": ("輸入快速鍵", "Typing shortcut"),
        "在光标位置输入最新复制的文字": ("在游標位置輸入最新複製的文字", "Type the latest copied text at the cursor"),
        "设置输入快捷键": ("設定輸入快速鍵", "Set typing shortcut"),
        "请按组合键…": ("請按組合鍵…", "Press a shortcut…"),
        "输入模式": ("輸入模式", "Input mode"),
        "普通模式": ("一般模式", "Normal"),
        "模拟输入": ("模擬輸入", "Simulated typing"),
        "一次写入整段文字": ("一次寫入整段文字", "Insert the full text at once"),
        "逐字输入，再次按快捷键或手动打字可停止": ("逐字輸入；再次按快速鍵或手動打字可停止", "Type character by character; press the shortcut again or type to stop"),
        "模拟输入速度": ("模擬輸入速度", "Typing speed"),
        "中速": ("中速", "Medium"),
        "快速": ("快速", "Fast"),
        "特别快": ("特別快", "Very fast"),
        "开机启动": ("開機啟動", "Launch at login"),
        "登录 Mac 后，自动在菜单栏等你": ("登入 Mac 後，自動在選單列等你", "Stay in the menu bar after you log in"),
        "第一次安装可能需要重新登录。": ("首次安裝可能需要重新登入。", "You may need to log out and back in after the first install."),
        "输入组件已安装，点击启动或修复。": ("輸入元件已安裝，點擊啟動或修復。", "Input method is installed. Start or repair it."),
        "先将复制鸭安装为 Mac 输入组件。": ("請先將複製鴨安裝為 Mac 輸入元件。", "Install CopyDuck as a Mac input method first."),
        "启用输入组件": ("啟用輸入元件", "Enable input method"),
        "启动输入组件": ("啟動輸入元件", "Start input method"),
        "安装输入组件": ("安裝輸入元件", "Install input method"),
        "前往系统设置允许开机启动": ("前往系統設定允許開機啟動", "Allow launch at login in System Settings"),
        "关掉窗口，鸭还在菜单栏。": ("關閉視窗後，鴨還在選單列。", "Close this window; the duck stays in the menu bar."),
        "准备好后，复制文字，再按快捷键。": ("準備好後，複製文字，再按快速鍵。", "Copy some text, then press the shortcut."),
        "快捷键已被占用，请换一个组合。": ("快速鍵已被占用，請換一組。", "That shortcut is in use. Choose another."),
        "请使用 ⌘、⌃ 或 ⌥ 加一个字母、数字或符号；Esc 取消。": ("請使用 ⌘、⌃ 或 ⌥ 加上字母、數字或符號；Esc 取消。", "Use ⌘, ⌃ or ⌥ with a letter, number or symbol; Esc cancels."),
        "这个快捷键已被占用，换一个试试。": ("這組快速鍵已被占用，請換一組。", "That shortcut is in use. Try another."),
        "请在系统设置的“登录项”中允许复制鸭。": ("請在系統設定的「登入項目」中允許複製鴨。", "Allow CopyDuck in System Settings → Login Items."),
        "开机启动未能更新：": ("開機啟動無法更新：", "Could not update launch at login: "),
        "输入组件已就绪，可以去输入框试试了。": ("輸入元件已就緒，可以在輸入框試試。", "Input method is ready. Try it in a text field."),
        "请注销并重新登录后，再点击启用。": ("請登出並重新登入，再點擊啟用。", "Log out and back in, then click Enable."),
        "已就绪": ("已就緒", "Ready"),
        "待设置": ("待設定", "Setup needed"),
        "输入最新文字": ("輸入最新文字", "Type latest text"),
        "停止输入": ("停止輸入", "Stop typing"),
        "设置…": ("設定…", "Settings…"),
        "退出复制鸭": ("結束複製鴨", "Quit CopyDuck"),
        "组件未能确认打开设置。请先从菜单栏退出复制鸭，再重试；若仍无响应，请注销并重新登录。": ("元件無法確認設定已開啟。請從選單列結束複製鴨後重試；若仍無回應，請登出並重新登入。", "The input method could not open Settings. Quit CopyDuck from the menu bar and retry; if it still does not respond, log out and back in."),
        "启动未完成：": ("啟動未完成：", "Could not start: "),
        "安装未完成：": ("安裝未完成：", "Could not install: "),
        "旧组件尚未退出，请从菜单栏退出复制鸭后再打开。": ("舊元件尚未結束，請從選單列結束複製鴨後再開啟。", "The old input method is still running. Quit CopyDuck from the menu bar and reopen it."),
        "暂时无法退出旧组件，请从菜单栏退出复制鸭后再打开。": ("暫時無法結束舊元件，請從選單列結束複製鴨後再開啟。", "Could not quit the old input method. Quit CopyDuck from the menu bar and reopen it."),
        "安装位置已有另一个同名应用，请先移走它。": ("安裝位置已有另一個同名應用程式，請先移走。", "Another app with the same name is at the install location. Move it first."),
        "安装包中缺少有效的输入组件，请重新下载或构建。": ("安裝包缺少有效的輸入元件，請重新下載或建置。", "The app bundle has no valid input method. Download or build it again."),
        "复制鸭无法启动": ("複製鴨無法啟動", "CopyDuck could not start"),
        "无法创建启动锁：": ("無法建立啟動鎖：", "Could not create startup lock: "),
        "剪贴板里没有文字，先复制一段文字吧。": ("剪貼簿沒有文字，請先複製一段文字。", "The clipboard has no text. Copy some text first."),
        "请先点一下要输入文字的位置，再按快捷键。": ("請先點選要輸入的位置，再按快速鍵。", "Click where you want to type, then press the shortcut."),
        "输入组件尚未启用，请打开设置完成启用。": ("輸入元件尚未啟用，請開啟設定完成啟用。", "The input method is not enabled. Open Settings to enable it."),
        "输入位置已改变，输入已停止。": ("輸入位置已改變，輸入已停止。", "The insertion point changed. Typing stopped."),
        "输入连接已改变，请重新触发输入。": ("輸入連線已改變，請重新觸發輸入。", "The input connection changed. Press the shortcut again."),
        "输入法已改变，本次输入已取消。": ("輸入法已改變，本次輸入已取消。", "The input method changed. This request was canceled."),
        "暂时无法切换输入组件，请重新启用后再试。": ("暫時無法切換輸入元件，請重新啟用後再試。", "Could not switch to CopyDuck. Enable it again and retry."),
        "没有连接到输入框。请松开快捷键，点一下输入位置后重试。": ("無法連接輸入框。請放開快速鍵，點選輸入位置後重試。", "Could not connect to the text field. Release the shortcut, click the field, and retry."),
        "输入位置已改变，请重新触发输入。": ("輸入位置已改變，請重新觸發輸入。", "The insertion point changed. Press the shortcut again.")
    ]

    static func text(_ key: String, language: AppLanguage = current) -> String {
        switch language {
        case .simplified: return key
        case .traditional: return translations[key]?.traditional ?? key
        case .english: return translations[key]?.english ?? key
        }
    }

    static func speedDetail(_ speed: TypingSpeed, language: AppLanguage) -> String {
        switch language {
        case .simplified: return "约每秒 \(speed.charactersPerSecond) 字"
        case .traditional: return "約每秒 \(speed.charactersPerSecond) 字"
        case .english: return "About \(speed.charactersPerSecond) characters/sec"
        }
    }

    static func countMessage(_ event: CountEvent, count: Int, language: AppLanguage = current) -> String {
        switch (language, event) {
        case (.simplified, .inserted): return "已向输入框写入 \(count) 个字符。"
        case (.traditional, .inserted): return "已向輸入框寫入 \(count) 個字元。"
        case (.english, .inserted): return "Inserted \(count) characters."
        case (.simplified, .simulated): return "已模拟输入 \(count) 个字符。"
        case (.traditional, .simulated): return "已模擬輸入 \(count) 個字元。"
        case (.english, .simulated): return "Simulated typing finished: \(count) characters."
        case (.simplified, .switchedApp): return "已切换应用，输入已停止（已输入 \(count) 字）。"
        case (.traditional, .switchedApp): return "已切換應用程式，輸入已停止（已輸入 \(count) 字）。"
        case (.english, .switchedApp): return "Switched apps. Typing stopped (\(count) characters entered)."
        case (.simplified, .movedFocus): return "输入位置已改变，模拟输入已停止（已输入 \(count) 字）。"
        case (.traditional, .movedFocus): return "輸入位置已改變，模擬輸入已停止（已輸入 \(count) 字）。"
        case (.english, .movedFocus): return "Insertion point changed. Simulated typing stopped (\(count) characters entered)."
        case (.simplified, .fieldClosed): return "输入框已关闭，输入已停止（已输入 \(count) 字）。"
        case (.traditional, .fieldClosed): return "輸入框已關閉，輸入已停止（已輸入 \(count) 字）。"
        case (.english, .fieldClosed): return "Text field closed. Typing stopped (\(count) characters entered)."
        case (.simplified, .stopped): return "已停止输入（已输入 \(count) 字）。"
        case (.traditional, .stopped): return "已停止輸入（已輸入 \(count) 字）。"
        case (.english, .stopped): return "Typing stopped (\(count) characters entered)."
        }
    }

    static func simulatedProgress(_ speed: TypingSpeed, language: AppLanguage = current) -> String {
        switch language {
        case .simplified: return "正在模拟输入（\(speed.title)），再次按快捷键可停止。"
        case .traditional: return "正在模擬輸入（\(text(speed.title, language: language))），再次按快速鍵可停止。"
        case .english: return "Simulated typing (\(text(speed.title, language: language))). Press the shortcut again to stop."
        }
    }

    static func shortcutSet(_ shortcut: String, language: AppLanguage = current) -> String {
        switch language {
        case .simplified: return "快捷键已设为 \(shortcut)。"
        case .traditional: return "快速鍵已設為 \(shortcut)。"
        case .english: return "Shortcut set to \(shortcut)."
        }
    }

    static func componentNotFound(_ status: Int32, language: AppLanguage = current) -> String {
        switch language {
        case .simplified: return "系统尚未发现输入组件（\(status)）。请注销并重新登录后，再点击启用。"
        case .traditional: return "系統尚未找到輸入元件（\(status)）。請登出並重新登入，再點擊啟用。"
        case .english: return "The system has not found the input method (\(status)). Log out and back in, then click Enable."
        }
    }
}
