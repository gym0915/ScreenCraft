# Recording Package Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 ScreenCraft 增加正式的 Recording Package 存储层，让录制产物能保存为可重新打开的可编辑项目包。

**Architecture:** 在现有 `RecordingProject` 聚合根和 `ProjectStoring` 协议基础上新增文件系统实现。项目包是一个目录，包含 `project.json`、固定子目录和可重建缓存；模型只保存包内相对路径，避免项目目录移动后媒体引用失效。

**Tech Stack:** Swift、Foundation `FileManager`、`JSONEncoder` / `JSONDecoder`、Swift Testing、Xcode macOS test target。

---

### Task 1: 包内路径模型

**Files:**
- Modify: `ScreenCraft/Core/ProjectStore/RecordingProject.swift`
- Test: `ScreenCraftTests/ProjectStore/RecordingProjectTests.swift`

**Step 1: Write the failing test**

新增测试：

```swift
@Test func projectMediaStoresPackageRelativePaths() {
    let media = ProjectMedia(
        screenVideoPath: "media/screen.mov",
        microphoneAudioPath: "media/microphone.m4a",
        mouseEventsPath: "events/mouse-events.json"
    )

    #expect(media.screenVideoPath == "media/screen.mov")
    #expect(media.microphoneAudioPath == "media/microphone.m4a")
    #expect(media.mouseEventsPath == "events/mouse-events.json")
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project ScreenCraft.xcodeproj -scheme ScreenCraft -destination 'platform=macOS' -only-testing:ScreenCraftTests/RecordingProjectTests
```

Expected: FAIL because `ProjectMedia` does not expose package-relative path fields.

**Step 3: Write minimal implementation**

Add optional `String` path fields to `ProjectMedia`, keep existing optional `URL` fields for spike compatibility, and update initializer.

**Step 4: Run test to verify it passes**

Run the same focused test command.

Expected: PASS.

---

### Task 2: 文件系统 ProjectStore 创建和读取项目包

**Files:**
- Modify: `ScreenCraft/Core/ProjectStore/ProjectStore.swift`
- Test: `ScreenCraftTests/ProjectStore/RecordingPackageStoreTests.swift`

**Step 1: Write the failing tests**

Create tests that:

- Save a project into a temporary store root.
- Verify package directories exist: `media/`, `events/`, `thumbnails/`, `cache/preview/`.
- Verify `project.json` exists.
- Reopen recent projects from disk and recover project name, timeline duration, style, trim, and media paths.

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project ScreenCraft.xcodeproj -scheme ScreenCraft -destination 'platform=macOS' -only-testing:ScreenCraftTests/RecordingPackageStoreTests
```

Expected: FAIL because `FileSystemProjectStore` does not exist.

**Step 3: Write minimal implementation**

Add `FileSystemProjectStore: ProjectStoring` with:

- `init(rootDirectory: URL, fileManager: FileManager = .default)`
- `save(_ project:)`
- `recentProjects()`
- directory creation for the package structure
- deterministic package folder name based on project id
- ISO-8601 JSON date encoding/decoding

**Step 4: Run test to verify it passes**

Run the same focused test command.

Expected: PASS.

---

### Task 3: 缓存可删除重建

**Files:**
- Modify: `ScreenCraft/Core/ProjectStore/ProjectStore.swift`
- Test: `ScreenCraftTests/ProjectStore/RecordingPackageStoreTests.swift`

**Step 1: Write the failing test**

Add a test that creates a file under `cache/preview/`, calls `rebuildCache(for:)`, then verifies `cache/preview/` exists and the old file is gone.

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project ScreenCraft.xcodeproj -scheme ScreenCraft -destination 'platform=macOS' -only-testing:ScreenCraftTests/RecordingPackageStoreTests
```

Expected: FAIL because cache rebuilding is not implemented.

**Step 3: Write minimal implementation**

Extend the concrete store with `rebuildCache(for projectID:) async throws`, removing `cache/` and recreating `cache/preview/`.

**Step 4: Run test to verify it passes**

Run the focused test command.

Expected: PASS.

---

### Task 4: 全量验证

**Files:**
- No production changes expected.

**Step 1: Run full test suite**

Run:

```bash
xcodebuild test -project ScreenCraft.xcodeproj -scheme ScreenCraft -destination 'platform=macOS'
```

Expected: `TEST SUCCEEDED`.

**Step 2: Inspect git diff**

Run:

```bash
git status --short
git diff -- ScreenCraft ScreenCraftTests docs/plans/2026-05-06-recording-package.md
```

Expected: only Recording Package files and tests changed.
