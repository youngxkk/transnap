# Transnap

Transnap 是一个 macOS 菜单栏翻译工具，主打“复制即翻”。它基于系统 `Translation` 能力做本地翻译，通过菜单栏面板、全局快捷键和双击 `⌘C` 快速唤起，适合处理阅读、聊天、文档里的碎片文本。

## 项目状态

这是一个可运行的 SwiftUI macOS 应用原型，已经具备核心翻译流程与本地历史记录能力。

当前已完成的部分：

- 菜单栏常驻入口
- 自动读取剪贴板文本
- 输入文本后手动翻译
- 双击 `⌘C` 触发快速翻译
- 全局快捷键唤起翻译窗口
- SwiftData 本地保存翻译历史
- 设置页可清空全部本地翻译历史
- 离线语言包页接入系统翻译资源状态查询与下载准备
- 设置页与历史页窗口

当前仍在完善的部分：

- `launchAtLogin` 等设置已落到本地存储，但还没有接入完整系统行为
- 测试文件目前还是模板状态

## 功能概览

### 1. 菜单栏翻译

点击菜单栏图标即可展开翻译面板。应用会优先把当前剪贴板中的文本填入输入框，减少一次粘贴动作。

### 2. 双击复制触发

监听两次连续的 `⌘C`，在短时间窗口内识别为快速翻译请求，并直接对剪贴板文本发起翻译。

这项能力依赖 macOS 辅助功能权限。

### 3. 全局快捷键

应用启动后会注册一个全局快捷键用于唤起主翻译窗口。默认快捷键由代码初始化为：

- `Shift + Option + T`

你也可以在设置页里重新录制快捷键。

### 4. 历史记录

每次成功翻译后都会生成一条 `TranslationRecord`，保存在本地 SwiftData 存储中。历史窗口支持：

- 查看原文与译文
- 查看语言方向与时间
- 复制历史译文
- 删除单条记录
- 清空全部历史记录

### 5. 语言方向判断

当源语言或目标语言设置为自动时，应用会结合：

- `NaturalLanguage` 的语言识别结果
- 当前系统偏好语言
- 用户在设置中选择的语言方向

自动决定翻译方向。

### 6. 离线语言包管理

设置页会读取系统 `Translation` 框架返回的语言资源状态，并在支持下载时调用 `prepareTranslation()` 触发系统准备离线翻译资源。

## 技术栈

- SwiftUI
- SwiftData
- macOS AppKit
- `Translation` 框架
- `NaturalLanguage` 框架
- Carbon Hot Key API
- Accessibility Event Tap

## 运行环境

根据工程配置，当前项目面向较新的 macOS / Xcode 环境。

建议：

- 使用最新可用的 Xcode 打开 [Transnap.xcodeproj](/Users/seal/code/transnap/Transnap.xcodeproj)
- 在支持 `Translation` 框架的 macOS 版本上运行
- 首次使用双击 `⌘C` 功能时，按系统提示授予辅助功能权限

## 本地运行

### 用 Xcode

1. 打开 [Transnap.xcodeproj](/Users/seal/code/transnap/Transnap.xcodeproj)
2. 选择 `Transnap` target
3. 直接运行

运行后应用会以菜单栏工具的形式存在，不会以普通 Dock 应用显示。

### 命令行构建

如果你本机已经装好对应版本的 Xcode，也可以在项目根目录执行：

```bash
xcodebuild -project Transnap.xcodeproj -scheme Transnap -configuration Debug build
```

## 权限说明

### 辅助功能权限

双击 `⌘C` 检测依赖 `CGEvent.tapCreate` 监听键盘事件，因此需要辅助功能权限。

### 剪贴板访问

应用会读取当前剪贴板中的纯文本内容，用于自动填充和快速翻译。

## 项目结构

```text
Transnap/
├── TransnapApp.swift                # 应用入口，初始化模型、菜单栏、快捷键、双击复制监听
├── ViewModels/
│   └── TransnapViewModel.swift      # 翻译流程、状态管理、历史写入
├── Models/
│   └── TranslationRecord.swift      # SwiftData 翻译记录模型
├── Services/
│   ├── ClipboardService.swift       # 剪贴板读写
│   ├── DoubleCopyMonitor.swift      # 双击 Cmd+C 检测
│   ├── GlobalHotkeyManager.swift    # 全局快捷键注册
│   ├── LanguageDirectionResolver.swift
│   ├── SettingsStore.swift          # 用户设置持久化
│   ├── ShortcutFormatter.swift
│   └── WindowCoordinator.swift      # 独立窗口管理
└── Views/
    ├── MenuBarRootView.swift        # 菜单栏主面板
    ├── SettingsView.swift           # 设置页
    ├── HistoryWindowView.swift      # 历史记录页
    └── AdaptiveTextEditor.swift
```

## 核心流程

1. 应用启动后初始化 SwiftData、设置存储、菜单栏入口、双击复制监听和全局快捷键
2. 用户通过菜单栏、快捷键或双击 `⌘C` 触发翻译
3. `TransnapViewModel` 读取文本并交给 `LanguageDirectionResolver` 判断源/目标语言
4. `TranslationSession` 执行翻译
5. 成功结果写入 `TranslationRecord`
6. 菜单栏面板和历史窗口展示最新结果

## 已知问题

- 历史保留上限设置已存储，但还没有真正裁剪历史数据
- 单元测试与 UI 测试尚未覆盖真实业务流程

## 后续可以继续做的方向

- 接入真正的开机启动能力
- 补齐历史记录清理和数量裁剪
- 把离线语言包页面接到真实系统能力
- 增加翻译失败重试与错误分类提示
- 补单元测试和 UI 自动化测试

## License

暂未添加 License。若准备开源，建议补充明确的许可证文件。
