import XCTest
@testable import GhosttyThemeSwitcher

final class GhosttyThemeSwitcherTests: XCTestCase {
    func testParsesGhosttyThemeFile() {
        let theme = GhosttyThemeFileParser.theme(
            from: sampleTheme(background: "#FFFFFF", foreground: "#111111"),
            name: "Sample Light",
            source: .bundled,
            fileName: "Sample Light"
        )

        XCTAssertEqual(theme?.title, "Sample Light")
        XCTAssertEqual(theme?.appearance, .light)
        XCTAssertEqual(theme?.paletteHex.count, 16)
        XCTAssertEqual(theme?.accentHex, "#444444")
    }

    func testRejectsThemeFileMissingRequiredColors() {
        let theme = GhosttyThemeFileParser.theme(
            from: "palette = 0=#000000",
            name: "Broken",
            source: .local
        )

        XCTAssertNil(theme)
    }

    func testCatalogMergePrefersLocalOverManagedOverBundled() throws {
        let temp = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let localDir = temp.appendingPathComponent("local")
        let managedDir = temp.appendingPathComponent("managed")
        try FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: managedDir, withIntermediateDirectories: true)

        try sampleTheme(background: "#000000", foreground: "#FFFFFF")
            .write(to: managedDir.appendingPathComponent("Demo"), atomically: true, encoding: .utf8)
        try sampleTheme(background: "#FFFFFF", foreground: "#000000")
            .write(to: localDir.appendingPathComponent("Demo"), atomically: true, encoding: .utf8)

        let bundled = makeTheme(name: "Demo", source: .bundled, background: "#111111")
        let catalog = ThemeCatalog(
            bundledThemes: [bundled],
            bundledThemeDirectory: nil,
            localThemeDirectories: [localDir],
            managedThemeDirectory: managedDir
        )

        XCTAssertEqual(catalog.themes.count, 1)
        XCTAssertEqual(catalog.themes.first?.source, .local)
        XCTAssertEqual(catalog.themes.first?.appearance, .light)
    }

    func testSearchMatchesIdTitleSourceAndAppearance() {
        let catalog = ThemeCatalog(
            bundledThemes: [
                makeTheme(name: "Solar Day", source: .bundled, background: "#FFFFFF"),
                makeTheme(name: "Night Owl", source: .bundled, background: "#000000"),
            ],
            bundledThemeDirectory: nil,
            localThemeDirectories: [],
            managedThemeDirectory: URL(fileURLWithPath: "/tmp/unused")
        )

        XCTAssertEqual(catalog.filteredThemes(query: "solar").map(\.title), ["Solar Day"])
        XCTAssertEqual(catalog.filteredThemes(query: "bundled").count, 2)
        XCTAssertEqual(catalog.filteredThemes(query: "", appearance: .dark).map(\.title), ["Night Owl"])
        XCTAssertTrue(catalog.filteredThemes(query: "missing").isEmpty)
    }

    func testReplacesExistingThemeLine() {
        let original = """
        font-size = 14
        theme = Catppuccin Mocha
        window-theme = auto
        """

        let updated = GhosttyConfigEditor.updatedConfigContent(
            original: original,
            themeValue: "Catppuccin Latte"
        )

        XCTAssertTrue(updated.contains("theme = Catppuccin Latte"))
        XCTAssertFalse(updated.contains("theme = Catppuccin Mocha"))
    }

    func testAppendsThemeLineWhenMissing() {
        let original = """
        font-size = 14
        window-theme = auto
        """

        let updated = GhosttyConfigEditor.updatedConfigContent(
            original: original,
            themeValue: "Catppuccin Frappe"
        )

        XCTAssertTrue(updated.hasSuffix("theme = Catppuccin Frappe\n"))
    }

    func testWritesSystemAppearanceThemePair() {
        let updated = GhosttyConfigEditor.updatedConfigContent(
            original: "font-size = 14\n",
            themeValue: "light:/tmp/Light,dark:/tmp/Dark"
        )

        XCTAssertTrue(updated.contains("theme = light:/tmp/Light,dark:/tmp/Dark"))
    }

    func testBundledThemeInstallsIntoManagedDirectory() throws {
        let temp = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let bundledDir = temp.appendingPathComponent("bundled")
        let managedDir = temp.appendingPathComponent("managed")
        try FileManager.default.createDirectory(at: bundledDir, withIntermediateDirectories: true)
        let sourceURL = bundledDir.appendingPathComponent("Demo")
        try sampleTheme(background: "#000000", foreground: "#FFFFFF")
            .write(to: sourceURL, atomically: true, encoding: .utf8)

        let bundled = makeTheme(name: "Demo", source: .bundled, background: "#000000", bundledFileName: "Demo")
        let catalog = ThemeCatalog(
            bundledThemes: [bundled],
            bundledThemeDirectory: bundledDir,
            localThemeDirectories: [],
            managedThemeDirectory: managedDir
        )

        let reference = try catalog.configReference(for: bundled)

        XCTAssertEqual(reference, managedDir.appendingPathComponent("Demo").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: reference))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundledDir.appendingPathComponent("User Theme").path))
    }

    private func sampleTheme(background: String, foreground: String) -> String {
        """
        palette = 0=#000000
        palette = 1=#111111
        palette = 2=#222222
        palette = 3=#333333
        palette = 4=#444444
        palette = 5=#555555
        palette = 6=#666666
        palette = 7=#777777
        palette = 8=#888888
        palette = 9=#999999
        palette = 10=#AAAAAA
        palette = 11=#BBBBBB
        palette = 12=#444444
        palette = 13=#DDDDDD
        palette = 14=#EEEEEE
        palette = 15=#FFFFFF
        background = \(background)
        foreground = \(foreground)
        selection-background = #222222
        """
    }

    private func makeTheme(
        name: String,
        source: ThemeSource,
        background: String,
        bundledFileName: String? = nil
    ) -> Theme {
        Theme(
            id: Theme.slug(for: name),
            title: name,
            ghosttyThemeName: name,
            source: source,
            appearance: Theme.appearance(forBackground: background),
            bundledFileName: bundledFileName,
            filePath: source == .bundled ? nil : "/tmp/\(name)",
            backgroundHex: background,
            surfaceHex: "#222222",
            overlayHex: "#888888",
            textHex: "#FFFFFF",
            subtextHex: "#777777",
            accentHex: "#444444",
            paletteHex: Array(repeating: "#000000", count: 16)
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GhosttyThemeSwitcherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
