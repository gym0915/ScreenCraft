# Phase G - Zoom Analyzer Recording Package TODO

## Scope

- Read package mouse events from `events/mouse-events.json`.
- Generate automatic zoom segments with `ZoomAnalyzer`.
- Persist generated segments into `project.json` at `timeline.zoomSegments`.
- Preserve existing manual zoom segments when automatic analysis is rerun.

## Status

- [x] Clean old `audio-spike` and `recording-package` worktrees.
- [x] Create branch worktree `zoom-analyzer-package-integration`.
- [x] Add package-store test for mouse events to persisted zoom segments.
- [x] Add package-store test for preserving manual zoom segments.
- [x] Implement `FileSystemProjectStore.analyzeZoomSegments`.
- [x] Run full `xcodebuild test -scheme ScreenCraft -destination 'platform=macOS'`.
- [x] Generate inspectable sample `.screencraft` package.

## Validation

Final validation package:

`/Users/steve/Library/Application Support/ScreenCraft/Recordings/phase-g-zoom-analyzer-sample.screencraft`
