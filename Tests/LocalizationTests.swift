import Foundation

@main struct LocalizationTests {
    static func main() {
        let suite = "com.copyduck.localization-test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Cannot create test preferences") }
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(AppLanguage.load(from: defaults) == .simplified)
        for language in AppLanguage.allCases {
            defaults.set(language.rawValue, forKey: "interfaceLanguage")
            precondition(AppLanguage.load(from: defaults) == language)
            precondition(!L10n.text("输入快捷键", language: language).isEmpty)
            precondition(!L10n.text("设置…", language: language).isEmpty)
            precondition(!L10n.speedDetail(.fast, language: language).isEmpty)
            precondition(!L10n.countMessage(.inserted, count: 42, language: language).isEmpty)
        }
        precondition(L10n.text("输入快捷键", language: .english) == "Typing shortcut")
        precondition(L10n.text("输入快捷键", language: .traditional) == "輸入快速鍵")
        precondition(L10n.countMessage(.inserted, count: 42, language: .english) == "Inserted 42 characters.")
        defaults.set("unknown", forKey: "interfaceLanguage")
        precondition(AppLanguage.load(from: defaults) == .simplified)
        print("PASS: three interface languages, saved selection, fallback, status text")
    }
}
