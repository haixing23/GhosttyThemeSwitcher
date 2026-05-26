import Foundation

struct ThemeCatalog: @unchecked Sendable {
    static let shared = ThemeCatalog()

    let themes: [Theme]

    private let bundledThemeDirectory: URL?
    private let managedThemeDirectory: URL
    private let fileManager: FileManager

    init(
        bundledThemes: [Theme] = ThemeCatalog.loadBundledThemes(),
        bundledThemeDirectory: URL? = ThemeCatalog.bundledThemeDirectory(),
        localThemeDirectories: [URL] = ThemeCatalog.defaultLocalThemeDirectories(),
        managedThemeDirectory: URL = ThemeCatalog.defaultManagedThemeDirectory(),
        fileManager: FileManager = .default
    ) {
        self.bundledThemeDirectory = bundledThemeDirectory
        self.managedThemeDirectory = managedThemeDirectory
        self.fileManager = fileManager

        let managedThemes = ThemeCatalog.loadThemes(in: managedThemeDirectory, source: .managed, fileManager: fileManager)
        let localThemes = localThemeDirectories.flatMap {
            ThemeCatalog.loadThemes(in: $0, source: .local, skipping: [managedThemeDirectory], fileManager: fileManager)
        }

        themes = ThemeCatalog.mergedThemes(bundled: bundledThemes, managed: managedThemes, local: localThemes)
    }

    func theme(withId id: String) -> Theme? {
        let needle = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return themes.first {
            $0.id.lowercased() == needle
                || $0.title.lowercased() == needle
                || $0.ghosttyThemeName.lowercased() == needle
        }
    }

    func filteredThemes(query: String, appearance: ThemeAppearance? = nil) -> [Theme] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return themes.filter { theme in
            (appearance == nil || theme.appearance == appearance)
                && (needle.isEmpty || theme.searchText.contains(needle))
        }
    }

    func configReference(for theme: Theme) throws -> String {
        switch theme.source {
        case .bundled:
            return try installBundledTheme(theme).path
        case .managed, .local:
            return theme.filePath ?? theme.ghosttyThemeName
        }
    }

    func installBundledTheme(_ theme: Theme) throws -> URL {
        guard let fileName = theme.bundledFileName,
              let sourceDirectory = bundledThemeDirectory else {
            return managedThemeDirectory.appendingPathComponent(theme.ghosttyThemeName)
        }

        let sourceURL = sourceDirectory.appendingPathComponent(fileName)
        let destinationURL = managedThemeDirectory.appendingPathComponent(fileName)

        try fileManager.createDirectory(at: managedThemeDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            let sourceData = try Data(contentsOf: sourceURL)
            let destinationData = try Data(contentsOf: destinationURL)
            if sourceData == destinationData {
                return destinationURL
            }
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func mergedThemes(bundled: [Theme], managed: [Theme], local: [Theme]) -> [Theme] {
        var byName: [String: Theme] = [:]

        for theme in bundled {
            byName[mergeKey(for: theme)] = theme
        }
        for theme in managed {
            byName[mergeKey(for: theme)] = theme
        }
        for theme in local {
            byName[mergeKey(for: theme)] = theme
        }

        var usedIds: [String: Int] = [:]
        return byName.values
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { theme in
                let count = usedIds[theme.id, default: 0]
                usedIds[theme.id] = count + 1
                guard count > 0 else { return theme }
                return theme.withId("\(theme.id)-\(count + 1)")
            }
    }

    static func loadBundledThemes() -> [Theme] {
        guard let url = bundledMetadataURL(),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("bundled theme metadata not found in bundle")
            return []
        }

        do {
            return try JSONDecoder().decode([Theme].self, from: data)
        } catch {
            assertionFailure("Failed to decode bundled themes: \(error)")
            return []
        }
    }

    static func loadThemes(in directory: URL, source: ThemeSource, skipping skippedDirectories: [URL] = [], fileManager: FileManager = .default) -> [Theme] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url in
            if skippedDirectories.contains(where: { url.path.hasPrefix($0.path + "/") || url.path == $0.path }) {
                return nil
            }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let data = try? Data(contentsOf: url),
                  let contents = String(data: data, encoding: .utf8) else {
                return nil
            }
            return GhosttyThemeFileParser.theme(
                from: contents,
                name: url.lastPathComponent,
                source: source,
                fileURL: url
            )
        }
    }

    static func defaultLocalThemeDirectories() -> [URL] {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return [
            home.appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/themes"),
            home.appendingPathComponent(".config/ghostty/themes"),
        ]
    }

    static func defaultManagedThemeDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/com.mitchellh.ghostty/themes/ghostty-theme-switcher")
    }

    private static func mergeKey(for theme: Theme) -> String {
        theme.ghosttyThemeName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func bundledMetadataURL() -> URL? {
        resourceCandidates(fileName: "bundled-themes.json").first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private static func bundledThemeDirectory() -> URL? {
        if let preservedDirectory = resourceCandidates(fileName: "BundledThemes").first(where: {
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }) {
            return preservedDirectory
        }

        return resourceCandidates(fileName: "bundled-themes.json")
            .first { FileManager.default.fileExists(atPath: $0.path) }?
            .deletingLastPathComponent()
    }

    private static func resourceCandidates(fileName: String) -> [URL] {
        let bundleName = "GhosttyThemeSwitcher_GhosttyThemeSwitcher.bundle"
        var candidates: [URL?] = [
            Bundle.main.resourceURL?
                .appendingPathComponent(bundleName)
                .appendingPathComponent(fileName),
            Bundle.main.bundleURL
                .appendingPathComponent(bundleName)
                .appendingPathComponent(fileName),
            Bundle.module.resourceURL?.appendingPathComponent(fileName),
        ]

        if fileName == "bundled-themes.json" {
            candidates.append(Bundle.module.url(forResource: "bundled-themes", withExtension: "json"))
            candidates.append(Bundle.module.url(forResource: "themes", withExtension: "json"))
        }

        return candidates.compactMap { $0 }
    }
}

private extension Theme {
    func withId(_ newId: String) -> Theme {
        Theme(
            id: newId,
            title: title,
            ghosttyThemeName: ghosttyThemeName,
            source: source,
            appearance: appearance,
            bundledFileName: bundledFileName,
            filePath: filePath,
            backgroundHex: backgroundHex,
            surfaceHex: surfaceHex,
            overlayHex: overlayHex,
            textHex: textHex,
            subtextHex: subtextHex,
            accentHex: accentHex,
            paletteHex: paletteHex
        )
    }
}
