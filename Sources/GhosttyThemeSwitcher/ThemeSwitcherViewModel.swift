import Combine
import Foundation

@MainActor
final class ThemeSwitcherViewModel: ObservableObject {
    enum Status {
        case idle
        case success
        case error
    }

    enum ApplyMode: String, CaseIterable, Identifiable {
        case single
        case system

        var id: String { rawValue }

        func displayName(isChinese: Bool) -> String {
            switch self {
            case .single: return isChinese ? "单主题" : "Single"
            case .system: return isChinese ? "跟随系统" : "Follow System"
            }
        }
    }

    @Published var currentThemeLine: String = ""
    @Published var statusMessage: String = ""
    @Published var selectedTheme: Theme?
    @Published var selectedLightTheme: Theme?
    @Published var selectedDarkTheme: Theme?
    @Published var status: Status = .idle
    @Published var applyMode: ApplyMode = .single
    @Published var searchQuery: String = ""
    @Published var lightSearchQuery: String = ""
    @Published var darkSearchQuery: String = ""

    let catalog: ThemeCatalog

    private var statusIsInitialPrompt = true
    private let language: LanguageManager
    private var cancellables = Set<AnyCancellable>()

    init(language: LanguageManager, catalog: ThemeCatalog = .shared) {
        self.language = language
        self.catalog = catalog
        currentThemeLine = language.t("Loading...", "正在加载……")
        statusMessage = language.t(
            "Search and apply a theme, or pair light and dark themes for macOS appearance.",
            "搜索并应用主题，或为 macOS 深浅色外观分别配对主题。"
        )
        selectedTheme = catalog.themes.first
        selectedLightTheme = catalog.filteredThemes(query: "", appearance: .light).first
        selectedDarkTheme = catalog.filteredThemes(query: "", appearance: .dark).first
        refresh()

        language.$preference
            .dropFirst()
            .sink { [weak self] _ in
                self?.relocalizeDefaults()
            }
            .store(in: &cancellables)
    }

    var filteredThemes: [Theme] {
        catalog.filteredThemes(query: searchQuery)
    }

    var filteredLightThemes: [Theme] {
        catalog.filteredThemes(query: lightSearchQuery, appearance: .light)
    }

    var filteredDarkThemes: [Theme] {
        catalog.filteredThemes(query: darkSearchQuery, appearance: .dark)
    }

    func refresh() {
        do {
            currentThemeLine = try GhosttyConfigEditor.readThemeLine() ?? "theme = <not set>"
        } catch {
            currentThemeLine = language.t(
                "Unable to read Ghostty config.",
                "无法读取 Ghostty 配置文件。"
            )
            statusMessage = error.localizedDescription
            statusIsInitialPrompt = false
            status = .error
        }
    }

    func apply(theme: Theme) {
        selectedTheme = theme
        do {
            statusMessage = try GhosttyConfigEditor.apply(theme: theme, catalog: catalog)
            statusIsInitialPrompt = false
            status = .success
            refresh()
        } catch {
            statusMessage = error.localizedDescription
            statusIsInitialPrompt = false
            status = .error
        }
    }

    func applySystemPair() {
        guard let selectedLightTheme, let selectedDarkTheme else {
            statusMessage = language.t(
                "Pick one light theme and one dark theme first.",
                "请先各选择一个浅色主题和深色主题。"
            )
            statusIsInitialPrompt = false
            status = .error
            return
        }

        do {
            statusMessage = try GhosttyConfigEditor.apply(
                lightTheme: selectedLightTheme,
                darkTheme: selectedDarkTheme,
                catalog: catalog
            )
            statusIsInitialPrompt = false
            status = .success
            refresh()
        } catch {
            statusMessage = error.localizedDescription
            statusIsInitialPrompt = false
            status = .error
        }
    }

    func openConfig() {
        GhosttyConfigEditor.openConfig()
    }

    private func relocalizeDefaults() {
        if statusIsInitialPrompt {
            statusMessage = language.t(
                "Search and apply a theme, or pair light and dark themes for macOS appearance.",
                "搜索并应用主题，或为 macOS 深浅色外观分别配对主题。"
            )
        }
        refresh()
    }
}
