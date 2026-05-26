import AppKit
import Foundation

enum GhosttyConfigEditor {
    static let configURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/config.ghostty")

    static func themeValue(for theme: Theme, catalog: ThemeCatalog = .shared) throws -> String {
        try catalog.configReference(for: theme)
    }

    static func themeValue(lightTheme: Theme, darkTheme: Theme, catalog: ThemeCatalog = .shared) throws -> String {
        let lightReference = try catalog.configReference(for: lightTheme)
        let darkReference = try catalog.configReference(for: darkTheme)
        return "light:\(lightReference),dark:\(darkReference)"
    }

    static func readThemeSetting() throws -> String? {
        guard let line = try readThemeLine() else { return nil }
        return line.split(separator: "=", maxSplits: 1)
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    static func apply(theme: Theme, catalog: ThemeCatalog = .shared) throws -> String {
        try apply(themeValue: themeValue(for: theme, catalog: catalog))
    }

    static func apply(lightTheme: Theme, darkTheme: Theme, catalog: ThemeCatalog = .shared) throws -> String {
        try apply(themeValue: themeValue(lightTheme: lightTheme, darkTheme: darkTheme, catalog: catalog))
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
                "Applied \(confirmedThemeLine). Ghostty reloaded automatically.",
                "已应用 \(confirmedThemeLine)。Ghostty 已自动重新加载。"
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
