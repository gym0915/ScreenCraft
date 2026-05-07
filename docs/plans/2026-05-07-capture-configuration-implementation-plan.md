# Capture Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 ScreenCaptureKit window spike 收敛成正式 capture 配置，统一支持 window、display、region，并在 UI 显示当前 capture resolution。

**Architecture:** `ScreenCaptureSource` 继续表示可选目标，新增正式 source/config metadata 表达 display/window/region、point rect、scale、capture pixel size 和质量提示。`ScreenCaptureKitScreenCaptureService` 负责把正式配置翻译成 `SCContentFilter` 与 `SCStreamConfiguration`，Home 只展示配置摘要并把输出写入 recording package 目录约定。

**Tech Stack:** Swift、SwiftUI、ScreenCaptureKit、Swift Testing、Xcode macOS target。

---

## Todo

- [x] 建模 `window/display/region` 三种 source/config。
- [x] 定义 Retina、多显示器、窗口尺寸变化下的 capture resolution 计算策略。
- [x] 在 ViewModel 暴露当前 source 的 capture resolution 和低分辨率提示。
- [x] 让真实 ScreenCaptureKit 服务能为 window/display/region 建立 stream configuration。
- [x] 把 screen video 输出路径切到 recording package 的 `media/screen.mov` 命名约定。
- [x] 更新 Home UI，从 Window Capture Spike 收敛为 Capture Configuration 面板。
- [x] 记录 Retina、多显示器、窗口尺寸变化的实现结论。
- [x] 自动化测试通过；手动完成一条 60 秒以上录制并记录可播放证据。

## Task 1: Capture 模型与 Resolution Policy

**Files:**
- Modify: `ScreenCraft/Core/Capture/ScreenCaptureModels.swift`
- Test: `ScreenCraftTests/Capture/ScreenCaptureModelsTests.swift`

**Steps:**
1. 写失败测试：window/display/region source 都能携带 point size、scale、capture pixel size。
2. 写失败测试：低于建议尺寸的窗口给出质量 warning。
3. 实现最小模型与计算逻辑。
4. 运行 `xcodebuild test -scheme ScreenCraft -destination 'platform=macOS' -only-testing:ScreenCraftTests/ScreenCaptureModelsTests`。

## Task 2: Home ViewModel Source Summary

**Files:**
- Modify: `ScreenCraft/Features/Home/HomeViewModel.swift`
- Test: `ScreenCraftTests/Home/HomeViewModelTests.swift`

**Steps:**
1. 写失败测试：刷新 source 后默认选择可录制 source 并展示 capture resolution。
2. 写失败测试：选择过小窗口时展示低分辨率提示。
3. 实现 ViewModel 派生属性，不在 View 层重复计算。
4. 运行 `xcodebuild test -scheme ScreenCraft -destination 'platform=macOS' -only-testing:ScreenCraftTests/HomeViewModelTests`。

## Task 3: ScreenCaptureKit 配置翻译

**Files:**
- Modify: `ScreenCraft/Core/Capture/ScreenCaptureKitScreenCaptureService.swift`
- Modify: `ScreenCraft/Core/Capture/ScreenCaptureService.swift`
- Test: `ScreenCraftTests/Capture/ScreenCaptureModelsTests.swift`

**Steps:**
1. 写失败测试覆盖 stream configuration 输入所需的纯计算部分。
2. 用 `SCContentFilter(display:excludingWindows:)` 支持 display。
3. 用 display + crop rect 策略支持 region。
4. window 继续保留 `.screen` stream output 和 `stopCapture()` 收尾策略。
5. 运行 Capture 测试和完整 build。

## Task 4: Package 输出路径

**Files:**
- Modify: `ScreenCraft/Core/Capture/ScreenCaptureModels.swift`
- Modify: `ScreenCraft/Core/Capture/ScreenCaptureService.swift`
- Modify: `ScreenCraft/Core/ProjectStore/RecordingProject.swift`
- Test: `ScreenCraftTests/Capture/ScreenCaptureModelsTests.swift`
- Test: `ScreenCraftTests/ProjectStore/RecordingProjectTests.swift`

**Steps:**
1. 写失败测试：配置可以生成 package root、`media/screen.mov` 和 `project.json` 需要的相对路径。
2. 实现正式文件命名，保留 spike 临时目录作为默认 root。
3. stop recording 返回包含 package-relative screen path 的 project。
4. 运行 Capture 与 ProjectStore 测试。

## Task 5: Home UI

**Files:**
- Modify: `ScreenCraft/Features/Home/HomeView.swift`
- Test: `ScreenCraftTests/Home/HomeViewModelTests.swift`

**Steps:**
1. 将 “Window Capture Spike” 改为 “Capture Configuration”。
2. Picker 展示 window/display/region，而不是只过滤 window。
3. 在状态面板显示 capture resolution、source kind、warning。
4. 运行完整 `xcodebuild test`。

## Task 6: Documentation and Manual Verification

**Files:**
- Create: `docs/spikes/2026-05-07-capture-configuration-results.md`
- Modify: `docs/plans/2026-05-06-screencraft-mvp-roadmap-and-control-plane.md`

**Steps:**
1. 记录 Retina scale 策略：points * source scale -> rounded pixel size。
2. 记录多显示器策略：display source 直接使用 display width/height；region 绑定 display + point rect + scale。
3. 记录窗口尺寸变化策略：start recording 时锁定 capture resolution，录制中窗口变化作为已知限制提示。
4. 手动录制 60 秒 window，使用 `ffprobe` 或 Quick Look 记录可播放证据。
