import AppKit
import Combine
import Foundation
import SwiftUI

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

struct Theme: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let ghosttyThemeName: String

    let backgroundHex: String
    let surfaceHex: String
    let overlayHex: String
    let textHex: String
    let subtextHex: String
    let accentHex: String
    let paletteHex: [String]

    private enum CodingKeys: String, CodingKey {
        case id, title, ghosttyThemeName
        case backgroundHex = "background"
        case surfaceHex = "surface"
        case overlayHex = "overlay"
        case textHex = "text"
        case subtextHex = "subtext"
        case accentHex = "accent"
        case paletteHex = "palette"
    }

    var background: Color { Theme.color(backgroundHex) }
    var surface: Color { Theme.color(surfaceHex) }
    var overlay: Color { Theme.color(overlayHex) }
    var text: Color { Theme.color(textHex) }
    var subtext: Color { Theme.color(subtextHex) }
    var accent: Color { Theme.color(accentHex) }
    var palette: [Color] { paletteHex.map(Theme.color) }

    /// Auto-derived from background brightness so JSON contributors don't have
    /// to pick an SF Symbol. Light backgrounds get a sun, dark backgrounds get
    /// a moon.
    var badgeSymbol: String {
        Theme.luminance(of: backgroundHex) > 0.5 ? "sun.max.fill" : "moon.stars.fill"
    }

    private static func color(_ hex: String) -> Color {
        let value = parseHex(hex)
        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    private static func luminance(of hex: String) -> Double {
        let value = parseHex(hex)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        // Perceived luminance (Rec. 601)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private static func parseHex(_ hex: String) -> UInt64 {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        return value
    }
}

enum ThemeLibrary {
    static let all: [Theme] = loadThemes()

    static func theme(withId id: String) -> Theme? {
        all.first { $0.id == id }
    }

    private static func loadThemes() -> [Theme] {
        guard let url = Bundle.module.url(forResource: "themes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("themes.json not found in bundle")
            return []
        }
        do {
            return try JSONDecoder().decode([Theme].self, from: data)
        } catch {
            assertionFailure("Failed to decode themes.json: \(error)")
            return []
        }
    }
}

enum GhosttyConfigEditor {
    static let configURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/config.ghostty")

    static func themeValue(for theme: Theme) -> String {
        theme.ghosttyThemeName
    }

    static func readThemeLine() throws -> String? {
        let contents = try String(contentsOf: configURL, encoding: .utf8)
        return contents.split(whereSeparator: \.isNewline).first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("theme =")
        }).map(String.init)
    }

    static func updatedConfigContent(original: String, themeValue: String) -> String {
        let themeLine = "theme = \(themeValue)"
        let lines = original.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var replaced = false

        let rewritten = lines.map { line -> String in
            let text = String(line)
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("theme =") {
                replaced = true
                return themeLine
            }
            return text
        }

        if replaced {
            return rewritten.joined(separator: "\n")
        }

        if rewritten.isEmpty {
            return themeLine + "\n"
        }

        return rewritten.joined(separator: "\n") + "\n" + themeLine + "\n"
    }

    static func apply(themeValue: String) throws -> String {
        let original = try String(contentsOf: configURL, encoding: .utf8)
        let updated = updatedConfigContent(original: original, themeValue: themeValue)
        let backupURL = configURL.deletingLastPathComponent().appendingPathComponent("config.ghostty.bak")

        try? FileManager.default.removeItem(at: backupURL)
        try original.write(to: backupURL, atomically: true, encoding: .utf8)
        try updated.write(to: configURL, atomically: true, encoding: .utf8)
        let confirmedThemeLine = try readThemeLine() ?? "theme = <unknown>"

        switch reloadGhostty() {
        case .reloaded:
            return L10n.t(
                "Applied \(confirmedThemeLine). Use Cmd+Shift+, to reload Ghostty, or restart Ghostty.",
                "已应用 \(confirmedThemeLine)。请使用 Cmd+Shift+, 重新加载 Ghostty 或者重启 Ghostty。"
            )
        case .savedOnly:
            return L10n.t(
                "Saved \(confirmedThemeLine). Open Ghostty and press Cmd+Shift+, to reload.",
                "已保存 \(confirmedThemeLine)。打开 Ghostty 后按 Cmd+Shift+, 即可手动重载。"
            )
        case .reloadFailed(let message):
            return L10n.t(
                "Saved \(confirmedThemeLine), but reload needs attention: \(message)",
                "已保存 \(confirmedThemeLine)，但自动重载未成功：\(message)"
            )
        }
    }

    static func openConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    private static func reloadGhostty() -> ReloadResult {
        let isRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.mitchellh.ghostty"
        ).isEmpty

        guard isRunning else {
            return .savedOnly
        }

        let script = """
        tell application "Ghostty"
            if (count of windows) is 0 then
                return "no-windows"
            end if
            perform action "reload_config" on focused terminal of selected tab of front window
            return "reloaded"
        end tell
        """

        let result = runAppleScript(script)
        switch result {
        case .success(let output):
            return output.contains("no-windows") ? .savedOnly : .reloaded
        case .failure(let message):
            let trimmed = message.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let fallback = L10n.t(
                "Automation permission may be blocked.",
                "自动化权限可能被系统阻止。"
            )
            return .reloadFailed(trimmed.isEmpty ? fallback : trimmed)
        }
    }

    private static func runAppleScript(_ source: String) -> AppleScriptRunResult {
        guard let script = NSAppleScript(source: source) else {
            return .failure(L10n.t(
                "Unable to prepare AppleScript.",
                "无法初始化 AppleScript。"
            ))
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let unknown = L10n.t("Unknown AppleScript error.", "未知的 AppleScript 错误。")
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? unknown

            if number == -1743 {
                return .failure(L10n.t(
                    "macOS blocked automation. Allow Ghostty Theme Switcher in System Settings > Privacy & Security > Automation, then try again.",
                    "macOS 阻止了自动化。请前往「系统设置 > 隐私与安全性 > 自动化」中允许 Ghostty Theme Switcher，然后再试一次。"
                ))
            }

            return .failure(message)
        }

        return .success(result.stringValue ?? "")
    }

    private enum AppleScriptRunResult {
        case success(String)
        case failure(String)
    }

    enum ReloadResult {
        case reloaded
        case savedOnly
        case reloadFailed(String)
    }
}

@MainActor
final class ThemeSwitcherViewModel: ObservableObject {
    enum Status {
        case idle
        case success
        case error
    }

    @Published var currentThemeLine: String = ""
    @Published var statusMessage: String = ""
    @Published var selectedTheme: Theme?
    @Published var status: Status = .idle

    /// True while `statusMessage` is showing the localizable initial prompt
    /// (so that switching language re-translates it). Becomes false after
    /// the first apply/error result, which is already-rendered text.
    private var statusIsInitialPrompt = true

    private let language: LanguageManager
    private var cancellables = Set<AnyCancellable>()

    init(language: LanguageManager) {
        self.language = language
        currentThemeLine = language.t("Loading...", "正在加载……")
        statusMessage = language.t(
            "Pick a flavor card to apply it to Ghostty.",
            "点击下方任意主题卡片即可应用到 Ghostty。"
        )
        refresh()

        language.$preference
            .dropFirst()
            .sink { [weak self] _ in
                self?.relocalizeDefaults()
            }
            .store(in: &cancellables)
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
        applyThemeValue(GhosttyConfigEditor.themeValue(for: theme))
    }

    func openConfig() {
        GhosttyConfigEditor.openConfig()
    }

    private func applyThemeValue(_ themeValue: String) {
        do {
            statusMessage = try GhosttyConfigEditor.apply(themeValue: themeValue)
            statusIsInitialPrompt = false
            status = .success
            refresh()
        } catch {
            statusMessage = error.localizedDescription
            statusIsInitialPrompt = false
            status = .error
        }
    }

    private func relocalizeDefaults() {
        if statusIsInitialPrompt {
            statusMessage = language.t(
                "Pick a flavor card to apply it to Ghostty.",
                "点击下方任意主题卡片即可应用到 Ghostty。"
            )
        }
        // Re-read the config: if there was a localized read-error fallback,
        // it gets translated; if it's a real "theme = …" line, it just refreshes.
        refresh()
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ThemeSwitcherViewModel
    @ObservedObject var language: LanguageManager

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.14), Color(red: 0.12, green: 0.11, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(ThemeLibrary.all) { theme in
                            ThemeCard(theme: theme, isSelected: viewModel.selectedTheme == theme) {
                                viewModel.apply(theme: theme)
                            }
                        }
                    }
                }
                .padding(28)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("Ghostty Theme Switcher", "Ghostty 主题切换器"))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(L10n.t(
                        "Built-in Catppuccin previews for one-click Ghostty theme switching.",
                        "内置 Catppuccin 主题预览，一键切换 Ghostty 配色。"
                    ))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Button(action: viewModel.openConfig) {
                        Label(
                            L10n.t("Reveal Ghostty Config", "在 Finder 中显示配置文件"),
                            systemImage: "folder"
                        )
                    }
                    .buttonStyle(TintedButtonStyle(fill: Color.white.opacity(0.08)))

                    languageMenu
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(viewModel.currentThemeLine, systemImage: "terminal")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))

                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(viewModel.statusMessage)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.74))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle, .success: return .green
        case .error: return .red
        }
    }

    private var languageMenu: some View {
        Menu {
            Picker(selection: $language.preference) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.displayName(isChinese: language.isChinese))
                        .tag(option)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                Text(language.preference.displayName(isChinese: language.isChinese))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let onApply: () -> Void

    var body: some View {
        Button(action: onApply) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(theme.title, systemImage: theme.badgeSymbol)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text(isSelected
                         ? L10n.t("Applied", "已应用")
                         : L10n.t("Click to Apply", "点击应用"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? theme.accent : theme.accent.opacity(0.14))
                        )
                }

                ThemePreview(theme: theme)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? theme.accent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

struct ThemePreview: View {
    let theme: Theme

    private let sampleFiles = ["cpp.cpp", "lua.lua", "py.py", "json.json", "README.md", "config.ghostty"]
    private let codeColumns = [
        ["struct Node {", "  color = accent", "  title = theme", "  surface = blend()", "}", "apply_theme()"],
        ["theme = Catppuccin", "palette = catppuccin", "background = preview", "render sidebar", "reload config", "done"]
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                Circle().fill(Color.orange.opacity(0.85)).frame(width: 6, height: 6)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 6, height: 6)

                Spacer()

                Text(theme.ghosttyThemeName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.subtext)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(theme.surface)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sampleFiles.enumerated()), id: \.offset) { index, file in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(theme.palette[index % theme.palette.count])
                                .frame(width: 5, height: 5)
                            Text(file)
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(index == 0 ? theme.accent : theme.subtext)
                        }
                    }

                    Spacer()
                }
                .padding(9)
                .frame(width: 95, alignment: .topLeading)
                .frame(minHeight: 105, alignment: .topLeading)
                .background(theme.surface.opacity(0.9))

                HStack(spacing: 0) {
                    ForEach(Array(codeColumns.enumerated()), id: \.offset) { columnIndex, column in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Text(columnIndex == 0 ? "preview.swift" : "ghostty.conf")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(theme.subtext)
                                Spacer()
                            }

                            ForEach(Array(column.enumerated()), id: \.offset) { rowIndex, line in
                                HStack(spacing: 5) {
                                    Text("\(rowIndex + 1)")
                                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                                        .foregroundStyle(theme.overlay)
                                        .frame(width: 10, alignment: .trailing)

                                    Text(lineForDisplay(line, row: rowIndex))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(colorForRow(rowIndex))
                                }
                            }

                            Spacer()
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                        if columnIndex == 0 {
                            Divider().overlay(theme.overlay.opacity(0.5))
                        }
                    }
                }
                .background(theme.background)
            }

            HStack(spacing: 3) {
                ForEach(Array(theme.palette.enumerated()), id: \.offset) { _, swatch in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(swatch)
                        .frame(height: 13)
                }
            }
            .padding(7)
            .background(theme.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.overlay.opacity(0.35), lineWidth: 1)
        )
    }

    private func colorForRow(_ row: Int) -> Color {
        let index = min(row + 1, theme.palette.count - 1)
        return theme.palette[index]
    }

    private func lineForDisplay(_ line: String, row: Int) -> String {
        if line.contains("Catppuccin") {
            return "theme = \(theme.ghosttyThemeName)"
        }
        if row == 2 {
            return "background = \(theme.title.lowercased())"
        }
        return line
    }
}

struct TintedButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.78 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
