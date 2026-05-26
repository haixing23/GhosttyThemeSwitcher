import Foundation
import SwiftUI

enum ThemeSource: String, Codable, CaseIterable, Sendable {
    case bundled
    case managed
    case local

    func displayName(isChinese: Bool) -> String {
        switch self {
        case .bundled: return isChinese ? "内置" : "Bundled"
        case .managed: return isChinese ? "已安装" : "Installed"
        case .local: return isChinese ? "本机" : "Local"
        }
    }
}

enum ThemeAppearance: String, Codable, CaseIterable, Sendable {
    case light
    case dark

    var badgeSymbol: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    func displayName(isChinese: Bool) -> String {
        switch self {
        case .light: return isChinese ? "浅色" : "Light"
        case .dark: return isChinese ? "深色" : "Dark"
        }
    }
}

struct Theme: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let title: String
    let ghosttyThemeName: String
    let source: ThemeSource
    let appearance: ThemeAppearance
    let bundledFileName: String?
    let filePath: String?

    let backgroundHex: String
    let surfaceHex: String
    let overlayHex: String
    let textHex: String
    let subtextHex: String
    let accentHex: String
    let paletteHex: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, ghosttyThemeName, source, appearance, bundledFileName, filePath
        case backgroundHex = "background"
        case surfaceHex = "surface"
        case overlayHex = "overlay"
        case textHex = "text"
        case subtextHex = "subtext"
        case accentHex = "accent"
        case paletteHex = "palette"
    }

    init(
        id: String,
        title: String,
        ghosttyThemeName: String,
        source: ThemeSource,
        appearance: ThemeAppearance,
        bundledFileName: String?,
        filePath: String?,
        backgroundHex: String,
        surfaceHex: String,
        overlayHex: String,
        textHex: String,
        subtextHex: String,
        accentHex: String,
        paletteHex: [String]
    ) {
        self.id = id
        self.title = title
        self.ghosttyThemeName = ghosttyThemeName
        self.source = source
        self.appearance = appearance
        self.bundledFileName = bundledFileName
        self.filePath = filePath
        self.backgroundHex = backgroundHex
        self.surfaceHex = surfaceHex
        self.overlayHex = overlayHex
        self.textHex = textHex
        self.subtextHex = subtextHex
        self.accentHex = accentHex
        self.paletteHex = paletteHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        ghosttyThemeName = try container.decode(String.self, forKey: .ghosttyThemeName)
        source = try container.decodeIfPresent(ThemeSource.self, forKey: .source) ?? .bundled
        bundledFileName = try container.decodeIfPresent(String.self, forKey: .bundledFileName)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        backgroundHex = try container.decode(String.self, forKey: .backgroundHex)
        surfaceHex = try container.decode(String.self, forKey: .surfaceHex)
        overlayHex = try container.decode(String.self, forKey: .overlayHex)
        textHex = try container.decode(String.self, forKey: .textHex)
        subtextHex = try container.decode(String.self, forKey: .subtextHex)
        accentHex = try container.decode(String.self, forKey: .accentHex)
        paletteHex = try container.decode([String].self, forKey: .paletteHex)
        appearance = try container.decodeIfPresent(ThemeAppearance.self, forKey: .appearance)
            ?? Theme.appearance(forBackground: backgroundHex)
    }

    var background: Color { Theme.color(backgroundHex) }
    var surface: Color { Theme.color(surfaceHex) }
    var overlay: Color { Theme.color(overlayHex) }
    var text: Color { Theme.color(textHex) }
    var subtext: Color { Theme.color(subtextHex) }
    var accent: Color { Theme.color(accentHex) }
    var palette: [Color] { paletteHex.map(Theme.color) }
    var badgeSymbol: String { appearance.badgeSymbol }

    var searchText: String {
        [
            id,
            title,
            ghosttyThemeName,
            source.rawValue,
            appearance.rawValue,
        ].joined(separator: " ").lowercased()
    }

    static func color(_ hex: String) -> Color {
        let value = parseHex(hex)
        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    static func appearance(forBackground hex: String) -> ThemeAppearance {
        luminance(of: hex) >= 0.5 ? .light : .dark
    }

    static func luminance(of hex: String) -> Double {
        let value = parseHex(hex)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    static func slug(for value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "theme" : collapsed.lowercased()
    }

    private static func parseHex(_ hex: String) -> UInt64 {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        return value
    }
}

enum GhosttyThemeFileParser {
    static func theme(from contents: String, name: String, source: ThemeSource, fileName: String? = nil, fileURL: URL? = nil) -> Theme? {
        var values: [String: String] = [:]
        var palette: [Int: String] = [:]

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }

            if parts[0] == "palette" {
                let paletteParts = parts[1].split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if paletteParts.count == 2, let index = Int(paletteParts[0]) {
                    palette[index] = normalizedHex(paletteParts[1])
                }
            } else {
                values[parts[0]] = normalizedHex(parts[1])
            }
        }

        guard let background = values["background"],
              let foreground = values["foreground"] else {
            return nil
        }

        let paletteHex = (0..<16).map { palette[$0] ?? foreground }
        guard paletteHex.count == 16 else { return nil }

        let surface = values["selection-background"] ?? palette[0] ?? background
        let overlay = palette[8] ?? values["selection-background"] ?? surface
        let subtext = palette[7] ?? foreground
        let accent = palette[12] ?? palette[4] ?? foreground

        return Theme(
            id: Theme.slug(for: name),
            title: name,
            ghosttyThemeName: name,
            source: source,
            appearance: Theme.appearance(forBackground: background),
            bundledFileName: fileName,
            filePath: fileURL?.path,
            backgroundHex: background,
            surfaceHex: surface,
            overlayHex: overlay,
            textHex: foreground,
            subtextHex: subtext,
            accentHex: accent,
            paletteHex: paletteHex
        )
    }

    private static func normalizedHex(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return trimmed }
        return trimmed.uppercased()
    }
}
