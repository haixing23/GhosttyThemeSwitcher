import SwiftUI

struct GhosttyThemeSwitcherApp: App {
    @StateObject private var language = LanguageManager.shared
    @StateObject private var viewModel = ThemeSwitcherViewModel(language: LanguageManager.shared)

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, language: language)
                .frame(minWidth: 1100, minHeight: 760)
        }
        .defaultSize(width: 1240, height: 820)
        .windowResizability(.contentSize)
    }
}

@main
enum GhosttyThemeSwitcherEntry {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let catalog = ThemeCatalog.shared

        if let action = CommandLineAction(arguments: arguments) {
            do {
                switch action {
                case .apply(let themeId):
                    guard let theme = catalog.theme(withId: themeId) else {
                        throw CommandLineError.unknownTheme(themeId)
                    }
                    let message = try GhosttyConfigEditor.apply(theme: theme, catalog: catalog)
                    print(message)
                case .applySystem(let lightThemeId, let darkThemeId):
                    guard let lightTheme = catalog.theme(withId: lightThemeId) else {
                        throw CommandLineError.unknownTheme(lightThemeId)
                    }
                    guard let darkTheme = catalog.theme(withId: darkThemeId) else {
                        throw CommandLineError.unknownTheme(darkThemeId)
                    }
                    let message = try GhosttyConfigEditor.apply(
                        lightTheme: lightTheme,
                        darkTheme: darkTheme,
                        catalog: catalog
                    )
                    print(message)
                case .list:
                    for theme in catalog.themes {
                        print("\(theme.id)\t\(theme.title)\t\(theme.source.rawValue)\t\(theme.appearance.rawValue)")
                    }
                }
                Foundation.exit(0)
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
                Foundation.exit(1)
            }
        }

        GhosttyThemeSwitcherApp.main()
    }
}

private enum CommandLineAction {
    case apply(String)
    case applySystem(String, String)
    case list

    init?(arguments: [String]) {
        guard let first = arguments.first else { return nil }

        if first == "--apply", arguments.count >= 2 {
            self = .apply(arguments[1])
            return
        }

        if first == "--apply-system", arguments.count >= 3 {
            self = .applySystem(arguments[1], arguments[2])
            return
        }

        if first == "--list" {
            self = .list
            return
        }

        return nil
    }
}

private enum CommandLineError: LocalizedError {
    case unknownTheme(String)

    var errorDescription: String? {
        switch self {
        case .unknownTheme(let theme):
            return "Unknown theme: \(theme). Run --list to see available themes."
        }
    }
}
