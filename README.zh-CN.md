# Ghostty 主题切换器

> 一个小巧的原生 macOS 应用，一键在 [Ghostty](https://ghostty.org/) 中切换 [Catppuccin](https://catppuccin.com/) 主题。

简体中文 · [English](README.md)

![Catppuccin](https://img.shields.io/badge/theme-Catppuccin-f5c2e7?style=flat-square)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?style=flat-square)
![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

## 截图

<!-- 把截图放进 `assets/` 文件夹，再取消下面这行的注释。 -->
<!-- ![主界面](assets/screenshot-main.png) -->
_截图稍后补上。_

## 特性

- 用真实的调色板预览全部四款 Catppuccin 风味 —— **Latte**、**Frappé**、**Macchiato**、**Mocha**。
- 点一下就改写 `config.ghostty`，并通过 AppleScript 自动让 Ghostty 重载配置。
- 每次写入前都会留一份 `config.ghostty.bak` 备份，避免误操作。
- 双语界面（English / 简体中文）：默认跟随 macOS 系统语言，也可在 App 内通过 🌐 菜单手动切换。
- 同一个可执行文件还自带命令行模式，方便脚本和 Shortcuts 调用。

## 系统要求

- macOS 13（Ventura）或更新版本
- 已安装 [Ghostty](https://ghostty.org/) 并放在 `/Applications` 目录

## 安装

### 方式一 —— 下载发行版

1. 在 [Releases](../../releases) 页面下载最新的 `.zip`。
2. 解压后把 **Ghostty Theme Switcher.app** 拖到 `/Applications` 文件夹里。
3. **首次打开**：因为本 App 没有花钱购买 Apple 开发者账号做签名，macOS 第一次会拦截它。**别双击**，按下面的步骤来：
   - 在「访达」里打开 `/Applications` 文件夹
   - 找到 **Ghostty Theme Switcher**，**右键**点击它（触控板用户可以按住 `Control` 键再点一下）
   - 在弹出的菜单里选「**打开**」
   - 系统再弹一次确认对话框，点「**打开**」即可
   - 之后每次双击都能正常启动。

> **如果 macOS 提示「App 已损坏，无法打开」**：这是因为浏览器下载的文件被系统打上了"隔离"标记，并不是 App 真的坏了。打开「终端」运行下面这行命令即可解决：
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Ghostty Theme Switcher.app"
> ```
> 然后再尝试打开 App。

### 方式二 —— 自己编译

```sh
git clone https://github.com/haixing23/GhosttyThemeSwitcher.git
cd GhosttyThemeSwitcher
zsh tools/build_app.sh
open dist/Ghostty\ Theme\ Switcher.app
```

打包好的 App 会出现在 `dist/` 目录里。

## 使用方法

1. 打开 App。
2. 点击任意主题卡片 —— 配置会立刻写入，运行中的 Ghostty 窗口也会马上重载新主题。

### 权限说明

第一次让 App 重载 Ghostty 时，macOS 会弹出 **自动化** 权限请求。如果不小心点了拒绝，可以到下面这里重新打开：

> 系统设置 → 隐私与安全性 → 自动化 → Ghostty Theme Switcher → Ghostty

### 命令行模式

同一个可执行文件也可以当 CLI 用，方便写 shell 脚本、Raycast 或快捷指令调用：

```sh
"/Applications/Ghostty Theme Switcher.app/Contents/MacOS/Ghostty Theme Switcher" --apply mocha
```

可选风味：`latte`、`frappe`、`macchiato`、`mocha`。

## 工作原理

App 会读取 `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`，替换（或追加）其中的 `theme = …` 行，然后用 AppleScript 通知正在运行的 Ghostty 重载配置。修改前的版本始终会保存为同目录下的 `config.ghostty.bak`。

## 项目结构

```
GhosttyThemeSwitcher/
├── Sources/
│   └── GhosttyThemeSwitcher/    # SwiftUI 界面 + CLI 入口
├── Tests/
│   └── GhosttyThemeSwitcherTests/
├── tools/
│   ├── build_app.sh             # 把 .app 打包到 dist/
│   ├── build_icon.sh
│   ├── Info.plist
│   └── AppIcon.iconset/
├── assets/                      # README 用的截图
├── Package.swift
├── LICENSE
└── README.md
```

## 参与贡献

欢迎提 Issue 或 PR。运行单元测试：

```sh
swift test
```

## 致谢

- [**Ghostty**](https://ghostty.org/) by Mitchell Hashimoto —— 让这个 App 有意义的终端。
- [**Catppuccin**](https://catppuccin.com/) —— 本 App 围绕展开的柔和配色主题。

衷心感谢这两个社区。❤️

## 开源协议

基于 [MIT 协议](LICENSE) 发布。

Catppuccin 配色由其社区所有，本项目仅按名称引用，未捆绑任何 Catppuccin 资源。
