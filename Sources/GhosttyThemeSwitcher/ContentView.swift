import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ThemeSwitcherViewModel
    @ObservedObject var language: LanguageManager

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.11), Color(red: 0.13, green: 0.12, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.applyMode {
            case .single:
                VStack(alignment: .leading, spacing: 18) {
                    header
                    modeControls
                    if let selectedTheme = viewModel.selectedTheme {
                        SelectedThemePreview(theme: selectedTheme, language: language)
                    }

                    ScrollView {
                        singleThemeGrid
                            .padding(.bottom, 28)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)

            case .system:
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        modeControls
                        systemPairPanel
                    }
                    .padding(28)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("Ghostty Theme Switcher", "Ghostty 主题切换器"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(L10n.t(
                        "\(viewModel.catalog.themes.count) Ghostty themes with search, previews, and system appearance pairing.",
                        "\(viewModel.catalog.themes.count) 款 Ghostty 主题，支持搜索、预览和系统深浅色配对。"
                    ))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
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

            statusPanel
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(viewModel.currentThemeLine, systemImage: "terminal")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(2)

            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.statusMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var modeControls: some View {
        HStack(spacing: 14) {
            ModeSwitch(selection: $viewModel.applyMode, language: language)
                .frame(width: 380)

            if viewModel.applyMode == .single {
                SearchField(
                    text: $viewModel.searchQuery,
                    placeholder: L10n.t("Search themes", "搜索主题")
                )
            } else {
                Spacer()
                Button(action: viewModel.applySystemPair) {
                    Label(L10n.t("Apply Pair", "应用配对"), systemImage: "circle.lefthalf.filled")
                }
                .buttonStyle(TintedButtonStyle(fill: Color(red: 0.12, green: 0.78, blue: 0.88)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var singleThemeGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.filteredThemes) { theme in
                ThemeCard(theme: theme, isSelected: viewModel.selectedTheme == theme, language: language) {
                    viewModel.apply(theme: theme)
                }
            }
        }
    }

    private var systemPairPanel: some View {
        HStack(alignment: .top, spacing: 18) {
            ThemePickerColumn(
                title: L10n.t("Light Theme", "浅色主题"),
                query: $viewModel.lightSearchQuery,
                selectedTheme: $viewModel.selectedLightTheme,
                themes: viewModel.filteredLightThemes,
                language: language
            )

            ThemePickerColumn(
                title: L10n.t("Dark Theme", "深色主题"),
                query: $viewModel.darkSearchQuery,
                selectedTheme: $viewModel.selectedDarkTheme,
                themes: viewModel.filteredDarkThemes,
                language: language
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
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}

struct ModeSwitch: View {
    @Binding var selection: ThemeSwitcherViewModel.ApplyMode
    @ObservedObject var language: LanguageManager

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ThemeSwitcherViewModel.ApplyMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: iconName(for: mode))
                            .font(.system(size: 13, weight: .bold))
                        Text(mode.displayName(isChinese: language.isChinese))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == mode ? Color(red: 0.04, green: 0.08, blue: 0.12) : Color.white.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selection == mode ? Color(red: 0.13, green: 0.86, blue: 0.93) : Color.white.opacity(0.055))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func iconName(for mode: ThemeSwitcherViewModel.ApplyMode) -> String {
        switch mode {
        case .single: return "rectangle.grid.2x2"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.white.opacity(0.68))
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.white.opacity(0.52)))
                .textFieldStyle(.plain)
                .foregroundStyle(Color.white)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.68))
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct ThemePickerColumn: View {
    let title: String
    @Binding var query: String
    @Binding var selectedTheme: Theme?
    let themes: [Theme]
    @ObservedObject var language: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text("\(themes.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
            }

            SearchField(text: $query, placeholder: L10n.t("Search", "搜索"))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(themes) { theme in
                        ThemePickerRow(
                            theme: theme,
                            isSelected: selectedTheme == theme,
                            language: language
                        ) {
                            selectedTheme = theme
                        }
                    }
                }
            }
            .frame(minHeight: 360, maxHeight: 520)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct ThemePickerRow: View {
    let theme: Theme
    let isSelected: Bool
    @ObservedObject var language: LanguageManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.background)
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(theme.accent, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                    Text("\(theme.source.displayName(isChinese: language.isChinese)) · \(theme.appearance.displayName(isChinese: language.isChinese))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? theme.accent : Color.white.opacity(0.34))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? theme.accent.opacity(0.85) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    @ObservedObject var language: LanguageManager
    let onApply: () -> Void

    var body: some View {
        Button(action: onApply) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label(theme.title, systemImage: theme.badgeSymbol)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer()
                    Text(isSelected
                         ? L10n.t("Applied", "已应用")
                         : L10n.t("Apply", "应用"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? theme.accent : theme.accent.opacity(0.14))
                        )
                }

                HStack(spacing: 6) {
                    ThemePill(text: theme.source.displayName(isChinese: language.isChinese), color: theme.accent)
                    ThemePill(text: theme.appearance.displayName(isChinese: language.isChinese), color: theme.text)
                }

                HStack(spacing: 3) {
                    ForEach(Array(theme.paletteHex.prefix(8).enumerated()), id: \.offset) { _, hex in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.color(hex))
                            .frame(height: 12)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? theme.accent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SelectedThemePreview: View {
    let theme: Theme
    @ObservedObject var language: LanguageManager

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Label(theme.title, systemImage: theme.badgeSymbol)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                HStack(spacing: 6) {
                    ThemePill(text: theme.source.displayName(isChinese: language.isChinese), color: theme.accent)
                    ThemePill(text: theme.appearance.displayName(isChinese: language.isChinese), color: theme.text)
                }

                Text(theme.ghosttyThemeName)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .lineLimit(2)
            }
            .frame(width: 260, alignment: .topLeading)

            ThemePreview(theme: theme)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct ThemePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.14))
            )
            .lineLimit(1)
    }
}

struct ThemePreview: View {
    let theme: Theme

    private let sampleFiles = ["cpp.cpp", "lua.lua", "py.py", "json.json", "README.md", "config.ghostty"]
    private let codeColumns = [
        ["struct Node {", "  color = accent", "  title = theme", "  surface = blend()", "}", "apply_theme()"],
        ["theme = selected", "palette = ghostty", "background = preview", "render sidebar", "reload config", "done"],
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
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(theme.surface)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sampleFiles.enumerated()), id: \.offset) { index, file in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(theme.palette[index % max(theme.palette.count, 1)])
                                .frame(width: 5, height: 5)
                            Text(file)
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(index == 0 ? theme.accent : theme.subtext)
                        }
                    }

                    Spacer()
                }
                .padding(8)
                .frame(width: 86, alignment: .topLeading)
                .frame(minHeight: 96, alignment: .topLeading)
                .background(theme.surface.opacity(0.9))

                HStack(spacing: 0) {
                    ForEach(Array(codeColumns.enumerated()), id: \.offset) { columnIndex, column in
                        VStack(alignment: .leading, spacing: 5) {
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
                                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                                        .foregroundStyle(colorForRow(rowIndex))
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(8)
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
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatch)
                        .frame(height: 11)
                }
            }
            .padding(7)
            .background(theme.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.overlay.opacity(0.35), lineWidth: 1)
        )
    }

    private func colorForRow(_ row: Int) -> Color {
        let index = min(row + 1, max(theme.palette.count - 1, 0))
        return theme.palette.isEmpty ? theme.text : theme.palette[index]
    }

    private func lineForDisplay(_ line: String, row: Int) -> String {
        if line.contains("selected") {
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
