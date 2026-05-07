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

        if let action = CommandLineAction(arguments: arguments) {
            do {
                switch action {
                case .apply(let theme):
                    let message = try GhosttyConfigEditor.apply(
                        themeValue: GhosttyConfigEditor.themeValue(for: theme)
                    )
                    print(message)
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
    case apply(Theme)

    init?(arguments: [String]) {
        guard let first = arguments.first else { return nil }

        if first == "--apply",
           arguments.count >= 2,
           let theme = ThemeLibrary.theme(withId: arguments[1].lowercased()) {
            self = .apply(theme)
            return
        }

        return nil
    }
}
