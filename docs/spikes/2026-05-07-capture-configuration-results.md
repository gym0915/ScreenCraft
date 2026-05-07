# Capture Configuration 阶段记录

日期：2026-05-07

## 已落地

- `ScreenCaptureSource.Kind` 支持 `window`、`display`、`region`。
- `CaptureSourceGeometry` 用 point rect + scale 计算 `CaptureResolution`。
- Home UI 展示当前 source kind、capture resolution 和低分辨率提示。
- ScreenCaptureKit 服务按 source kind 建立 filter：
  - window：`SCContentFilter(desktopIndependentWindow:)`
  - display：`SCContentFilter(display:excludingWindows:)`
  - region：display filter + `SCStreamConfiguration.sourceRect`
- 录制输出进入正式 package 路径：`*.screencraft/media/screen.mov`。
- `RecordingProject.media.screenVideoPath` 写入 `media/screen.mov`，便于后续重新打开项目。

## Resolution Policy

window 和 region 使用：

```text
captureWidth = round(pointWidth * scale)
captureHeight = round(pointHeight * scale)
```

display source 当前使用 ScreenCaptureKit 的 display pixel width/height 作为 capture resolution，scale 固定为 `1`，避免把系统已经给出的像素尺寸再乘一次。

最低输出尺寸先按 1080p 横屏素材的最低可用输入记录为 `1280 x 720`。窗口 capture resolution 低于该尺寸时，UI 显示提示：建议放大窗口再录制，以避免后续 1080p 导出变糊。

## Retina 和多显示器

- Retina window：通过 `SCContentFilter.pointPixelScale` 获取 window scale，按 point size 乘 scale 计算像素分辨率。
- Display：使用每个 `SCDisplay` 独立建模，source id 为 `display-<displayID>`。
- Region：当前为每个 display 生成一个默认居中 region source，最大 `1920 x 1080` 像素；后续选区 UI 会把用户拖拽结果替换为真实 region rect。

## 窗口尺寸变化

录制开始时锁定 `SCStreamConfiguration.width/height`。录制中窗口尺寸变化不会动态修改 capture resolution；这是当前阶段的明确限制。后续如果需要动态窗口跟随，应独立验证 ScreenCaptureKit 在 resize 时的帧行为和 `SCRecordingOutput` 收尾稳定性。

## Clamshell 外接屏窗口分辨率问题

用户在 MacBook Pro 开盖双屏时刷新 Codex 最大化窗口，capture resolution 为 `3456 x 1996`；合盖后同一窗口移动到 DELL U3223QE 外接 4K 屏并保持最大化，刷新后变成 `440 x 360`，真实录制产物为 `440 x 354`。这证明问题不只是 UI 预估错误，而是录制配置实际使用了错误的低分辨率。

根因判断：window source 不能依赖 `SCWindow.frame` 作为录制尺寸；clamshell / display topology 切换后，`SCWindow.frame` 可能返回 stale 或非内容尺寸。修正为优先使用 `SCContentFilter(desktopIndependentWindow:)` 的 `contentRect * pointPixelScale` 来构造 window geometry 和 `SCStreamConfiguration.width/height`。已增加回归测试覆盖 stale frame `440 x 354` 但 filter content rect 正常的情况。

## 尚需手动验证

- [x] 真实 capture source 录制 60 秒以上，确认 `*.screencraft/media/screen.mov` 可播放。
  - 验收文件：`/Users/steve/Library/Containers/com.steve.screencraft/Data/tmp/ScreenCraft/WindowCaptureSpike/region-display-2-20260507-025314.screencraft/media/screen.mov`
  - 用户手动验证：可以录制，可以播放。
  - `ffprobe` 元数据：H.264，1920x1080，84.55 秒，约 17 MB。
- [x] Retina 外接多显示器下刷新 source，确认 display/window/region resolution 文案符合预期。
  - 用户手动验证：内建 Retina 与 DELL U3223QE 外接 4K 显示器下刷新 source，展开窗口时 resolution 文案符合当前窗口和显示器状态。
  - Stage Manager / 前台调度侧边窗口会按缩略状态计算 capture resolution；录制前必须将目标窗口恢复到前台展开状态。
- [x] 缩小窗口到低于 `1280 x 720`，确认 UI 显示低分辨率提示。
  - 用户手动验证：窗口缩小或被前台调度收纳到侧边时，UI 显示低分辨率 warning，例如 `294 x 194` 并提示放大窗口后再录制。
