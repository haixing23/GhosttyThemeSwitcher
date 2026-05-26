import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    static let storageKey = "appLanguagePreference"

    static var current: AppLanguage {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return AppLanguage(rawValue: saved) ?? .system
    }

    var isChineseResolved: Bool {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? ""
            return preferred.hasPrefix("zh")
        case .english: return false
        case .chinese: return true
        }
    }

    func displayName(isChinese: Bool) -> String {
        switch self {
        case .system: return isChinese ? "跟随系统" : "System"
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var preference: AppLanguage {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: AppLanguage.storageKey)
        }
    }

    private init() {
        self.preference = AppLanguage.current
    }

    var isChinese: Bool { preference.isChineseResolved }

    func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }
}

enum L10n {
    static var isChinese: Bool { AppLanguage.current.isChineseResolved }

    static func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }
}
