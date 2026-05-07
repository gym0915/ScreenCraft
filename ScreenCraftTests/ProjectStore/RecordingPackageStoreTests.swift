import Foundation
import Testing
@testable import ScreenCraft

@MainActor
struct RecordingPackageStoreTests {
    @Test func saveCreatesPackageStructureAndProjectManifest() async throws {
        let rootDirectory = try temporaryRootDirectory()
        let store = FileSystemProjectStore(rootDirectory: rootDirectory)
        let project = RecordingProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
            name: "Package Test",
            createdAt: Date(timeIntervalSince1970: 100),
            media: ProjectMedia(
                screenVideoPath: "media/screen.mov",
                microphoneAudioPath: "media/microphone.m4a",
                mouseEventsPath: "events/mouse-events.json"
            ),
            timeline: Timeline(duration: 12)
        )

        try await store.save(project)

        let packageURL = store.packageURL(for: project.id)
        #expect(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("project.json").path))
        #expect(isDirectory(packageURL.appendingPathComponent("media")))
        #expect(isDirectory(packageURL.appendingPathComponent("events")))
        #expect(isDirectory(packageURL.appendingPathComponent("thumbnails")))
        #expect(isDirectory(packageURL.appendingPathComponent("cache/preview")))
    }

    @Test func recentProjectsReopensSavedPackageProject() async throws {
        let rootDirectory = try temporaryRootDirectory()
        let store = FileSystemProjectStore(rootDirectory: rootDirectory)
        let project = RecordingProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000602")!,
            name: "Recovered Project",
            createdAt: Date(timeIntervalSince1970: 200),
            media: ProjectMedia(
                screenVideoPath: "media/screen.mov",
                microphoneAudioPath: "media/microphone.m4a",
                mouseEventsPath: "events/mouse-events.json"
            ),
            timeline: Timeline(
                duration: 30,
                trim: TrimRange(start: 2, end: 24),
                style: ProjectStyle(background: "#20242A", padding: 64, cornerRadius: 18)
            )
        )

        try await store.save(project)
        let reopenedStore = FileSystemProjectStore(rootDirectory: rootDirectory)

        let projects = try await reopenedStore.recentProjects()

        #expect(projects == [project])
        #expect(projects.first?.media.screenVideoPath == "media/screen.mov")
        #expect(projects.first?.timeline.trim == TrimRange(start: 2, end: 24))
        #expect(projects.first?.timeline.style.background == "#20242A")
    }

    @Test func rebuildCacheRemovesPreviewFilesAndRecreatesCacheDirectory() async throws {
        let rootDirectory = try temporaryRootDirectory()
        let store = FileSystemProjectStore(rootDirectory: rootDirectory)
        let project = RecordingProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000603")!,
            name: "Cache Project",
            duration: 10
        )

        try await store.save(project)
        let previewDirectory = store.packageURL(for: project.id)
            .appendingPathComponent("cache/preview", isDirectory: true)
        let stalePreview = previewDirectory.appendingPathComponent("frame-0001.jpg")
        try Data("stale".utf8).write(to: stalePreview)

        try await store.rebuildCache(for: project.id)

        #expect(isDirectory(previewDirectory))
        #expect(!FileManager.default.fileExists(atPath: stalePreview.path))
    }

    @Test func saveWritesManifestAndMouseEventsIntoExistingMediaPackage() async throws {
        let rootDirectory = try temporaryRootDirectory()
        let packageURL = rootDirectory.appendingPathComponent("window-42-20260507-000000.screencraft", isDirectory: true)
        let mediaDirectory = packageURL.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let screenVideoURL = mediaDirectory.appendingPathComponent("screen.mov")
        try Data("screen".utf8).write(to: screenVideoURL)

        let store = FileSystemProjectStore(rootDirectory: rootDirectory)
        let project = RecordingProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000604")!,
            name: "Integrated Package",
            createdAt: Date(timeIntervalSince1970: 400),
            media: ProjectMedia(
                screenVideoURL: screenVideoURL,
                screenVideoPath: "media/screen.mov",
                mouseEventsPath: "events/mouse-events.json"
            ),
            duration: 5
        )
        let events = [
            MouseEvent(
                kind: .leftClick,
                timestamp: 1.25,
                globalLocation: MouseEventLocation(x: 120, y: 230),
                recordingLocation: MouseEventLocation(x: 40, y: 60)
            )
        ]

        try await store.save(project, mouseEvents: events)

        #expect(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("project.json").path))
        #expect(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("events/mouse-events.json").path))
        #expect(!FileManager.default.fileExists(atPath: store.packageURL(for: project.id).appendingPathComponent("project.json").path))

        let reopened = try await store.recentProjects()
        #expect(reopened == [project])

        let eventData = try Data(contentsOf: packageURL.appendingPathComponent("events/mouse-events.json"))
        let decodedEvents = try JSONDecoder.screenCraft.decode([MouseEvent].self, from: eventData)
        #expect(decodedEvents == events)
    }

    private func temporaryRootDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenCraftRecordingPackageTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
