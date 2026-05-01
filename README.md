# Transnap

Transnap 是一个 macOS 菜单栏翻译工具，主打“复制即翻”。它基于系统 `Translation` 框架进行本机翻译，通过菜单栏面板、全局快捷键和可选的双击复制快捷方式快速唤起，适合处理阅读、聊天、文档里的碎片文本。

当前发布候选版本：

- Version: `1.1.1`
- Build: `11`
- Bundle ID: `com.superaistorm.transnap`
- Minimum macOS: `15.0`

## 功能概览

### 菜单栏翻译

Transnap 启动后常驻菜单栏。点击菜单栏图标会展开翻译面板，并自动读取当前剪贴板中的纯文本填入输入框。

翻译面板支持：

- 自动读取剪贴板内容
- 手动输入或粘贴文本
- 自动或手动选择源语言与目标语言
- 一键复制译文
- 打开历史窗口和设置窗口

### 快捷键

默认全局快捷键：

- `Command + Shift + C`

用户可以在设置页重新录制快捷键。

设置页还可以手动启用 `Command + C + C`，也就是按住 `Command` 连按两次 `C`。这个功能会在复制后快速显示翻译面板，需要 macOS“输入监控”权限；未开启权限时，默认全局快捷键和菜单栏点击仍可正常使用。

### 语言与显示

设置页支持：

- 应用显示语言：简体中文、English
- 外观：跟随系统、浅色、深色
- 常用自动检测语言对
- 翻译面板源语言和目标语言选择

自动检测模式会在用户设置的两种常用语言之间判断；其它语言可以在翻译面板中手动指定。

### 历史记录

每次成功翻译后都会生成一条 `TranslationRecord`，并通过 SwiftData 保存在本机。

历史窗口支持：

- 查看原文与译文
- 查看语言方向与时间
- 复制历史译文
- 删除单条记录
- 清空全部历史记录

设置页可以调整最多保存条数。新翻译写入后，应用会按设置的上限裁剪较旧记录。

### 开机启动

设置页支持“登录时自动打开”，通过 `SMAppService.mainApp` 接入 macOS 登录项。部分系统状态可能需要用户在系统设置的登录项中确认一次。

### 离线语言包

离线语言包页会读取系统 `Translation` 框架返回的语言资源状态，并在支持下载时通过 `prepareTranslation()` 触发系统准备离线翻译资源。已下载语言包由 macOS 系统设置统一管理。

## 权限说明

### 剪贴板

Transnap 会读取当前剪贴板中的纯文本，用于自动填充和快速翻译。翻译历史只保存在本机，不会上传到外部服务。

### 输入监控

只有用户手动启用 `Command + C + C` 时，Transnap 才会请求输入监控权限。该功能只监听 `Command + C + C` 这个快捷方式，用于复制后快速显示翻译面板；未授权时应用会自动停用该功能。

## 技术栈

- SwiftUI
- AppKit
- SwiftData
- Translation framework
- NaturalLanguage framework
- Carbon Hot Key API
- ServiceManagement

## 本地运行

### 用 Xcode

1. 打开 [Transnap.xcodeproj](/Users/seal/code/Transnap/Transnap.xcodeproj)
2. 选择 `Transnap` scheme
3. 直接运行

运行后应用会以菜单栏工具形式存在，不会显示为普通 Dock 应用。

### 命令行构建

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap -configuration Debug build
```

Release 构建：

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap -configuration Release -destination platform=macOS build
```

运行单元测试：

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap -destination platform=macOS -only-testing:TransnapTests test
```

## 提交 App Store 前检查

建议通过 Xcode Organizer 走完整流程：

1. Product > Archive
2. Validate App
3. Distribute App / Upload

提交前重点确认：

- 版本号为 `1.1.1`
- Build 号为 `11` 或更高
- Bundle ID 为 `com.superaistorm.transnap`
- Archive 产物包含 `arm64` 和 `x86_64`
- App Sandbox 已开启
- 最终上传包使用 App Store 分发签名，而不是本地开发签名
- 不要上传本地调试生成的 `.dmg`、`.xcarchive`、`.xcresult` 或 DerivedData

## 项目结构

```text
Transnap/
├── TransnapApp.swift                # 应用入口，初始化模型、菜单栏、设置和快捷键
├── Models/
│   └── TranslationRecord.swift      # SwiftData 翻译记录模型
├── Services/
│   ├── AppSettingsController.swift  # 外观和登录项同步
│   ├── ClipboardService.swift       # 剪贴板读写
│   ├── GlobalHotkeyManager.swift    # 全局快捷键和双击复制监听
│   ├── LanguageDirectionResolver.swift
│   ├── MenuBarController.swift      # 菜单栏状态项与弹窗
│   ├── OfflineLanguageManager.swift # 离线语言包状态和下载准备
│   ├── SettingsStore.swift          # 用户设置持久化
│   ├── ShortcutFormatter.swift
│   └── WindowCoordinator.swift      # 历史与设置窗口管理
├── ViewModels/
│   └── TransnapViewModel.swift      # 翻译流程、状态管理、历史写入和裁剪
└── Views/
    ├── AdaptiveTextEditor.swift
    ├── HistoryWindowView.swift
    ├── LoadingSpinner.swift
    ├── MenuBarRootView.swift
    └── SettingsView.swift
```

## License

暂未添加 License。若准备开源，建议补充明确的许可证文件。
