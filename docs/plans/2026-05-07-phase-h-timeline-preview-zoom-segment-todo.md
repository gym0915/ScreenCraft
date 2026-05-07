# Phase H - Timeline Preview / Zoom Segment 可视化 TODO

## Scope

- 建立 `timeline-preview-zoom-segment` 分支工作树。
- 为 `Timeline` 增加轻量 preview presentation model。
- 将 `ZoomSegment` 映射为时间轴上的起点比例、宽度比例、来源和倍率。
- 停止录制并完成 zoom analysis 后，在 Home 控制面板展示最新项目的 Timeline Preview。
- 提供可手动验证的 UI 路径。

## Status

- [x] 从 `main` 创建工作树 `.worktrees/timeline-preview-zoom-segment`。
- [x] 跑基线 `xcodebuild test -scheme ScreenCraft -destination 'platform=macOS'`。
- [x] 添加 Timeline Preview 映射测试。
- [x] 添加 HomeViewModel 发布 preview 测试。
- [x] 实现 Timeline Preview presentation model。
- [x] 在 Home UI 中展示 Timeline Preview 面板。
- [x] 跑针对性测试。
- [x] 跑最终完整测试。

## Manual Validation

1. 在 Xcode 打开工作树项目：
   `/Users/steve/ClaudeWork/DevWork/RecordScreen/ScreenCraft/.worktrees/timeline-preview-zoom-segment/ScreenCraft.xcodeproj`
2. 运行 `ScreenCraft` scheme。
3. 点击 `Refresh Sources`，选择一个 window 或 region。
4. 点击 `Start Recording Source`。
5. 在被录制区域内点击一次或多次鼠标。
6. 点击 `Stop Recording`。
7. 滚动到 `Timeline Preview` 区域，确认：
   - 显示最新项目名、Duration 和 Trim。
   - 时间条上出现蓝色 zoom segment。
   - 下方列表显示 `Auto`、起止时间和倍率，例如 `2.0x`。
   - 如果没有点击事件，则显示 `No zoom segments generated.`。
