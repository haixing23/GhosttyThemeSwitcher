import XCTest
@testable import GhosttyThemeSwitcher

final class GhosttyThemeSwitcherTests: XCTestCase {
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
}
