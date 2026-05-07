import Foundation

@MainActor
protocol ProjectStoring: AnyObject {
    // 存储边界运行在 MainActor，当前调用方可以直接把结果映射到 SwiftUI 状态。
    func recentProjects() async throws -> [RecordingProject]
    func save(_ project: RecordingProject) async throws
    func save(_ project: RecordingProject, mouseEvents: [MouseEvent]) async throws
    func analyzeZoomSegments(
        for project: RecordingProject,
        configuration: ZoomAnalysisConfiguration
    ) async throws -> RecordingProject
}

@MainActor
final class FileSystemProjectStore: ProjectStoring {
    private let rootDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    func recentProjects() async throws -> [RecordingProject] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return []
        }

        let packageURLs = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil
        )

        let projects = try packageURLs.compactMap { packageURL -> RecordingProject? in
            let manifestURL = packageURL.appendingPathComponent(Self.manifestFileName)
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                return nil
            }

            let data = try Data(contentsOf: manifestURL)
            return try Self.decoder.decode(RecordingProject.self, from: data)
        }

        return projects.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ project: RecordingProject) async throws {
        try await save(project, mouseEvents: [])
    }

    func save(_ project: RecordingProject, mouseEvents: [MouseEvent]) async throws {
        let packageURL = packageURL(for: project)
        try createPackageDirectories(at: packageURL)

        if let mouseEventsPath = project.media.mouseEventsPath {
            let eventsData = try JSONEncoder.screenCraft.encode(mouseEvents)
            try eventsData.write(
                to: packageURL.appendingPathComponent(mouseEventsPath),
                options: [.atomic]
            )
        }

        let data = try JSONEncoder.screenCraft.encode(project)
        try data.write(
            to: packageURL.appendingPathComponent(Self.manifestFileName),
            options: [.atomic]
        )
    }

    func rebuildCache(for projectID: UUID) async throws {
        let cacheURL = packageURL(for: projectID).appendingPathComponent("cache", isDirectory: true)
        if fileManager.fileExists(atPath: cacheURL.path) {
            try fileManager.removeItem(at: cacheURL)
        }

        try fileManager.createDirectory(
            at: cacheURL.appendingPathComponent("preview", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func analyzeZoomSegments(
        for project: RecordingProject,
        configuration: ZoomAnalysisConfiguration
    ) async throws -> RecordingProject {
        let packageURL = packageURL(for: project)
        let manifestURL = packageURL.appendingPathComponent(Self.manifestFileName)
        let data = try Data(contentsOf: manifestURL)
        var project = try JSONDecoder.screenCraft.decode(RecordingProject.self, from: data)

        guard let mouseEventsPath = project.media.mouseEventsPath else {
            project.timeline.zoomSegments = []
            try await save(project)
            return project
        }

        let eventsURL = packageURL.appendingPathComponent(mouseEventsPath)
        let eventsData = try Data(contentsOf: eventsURL)
        let events = try JSONDecoder.screenCraft.decode([MouseEvent].self, from: eventsData)

        let manualSegments = project.timeline.zoomSegments.filter { $0.source == .manual }
        let automaticSegments = ZoomAnalyzer(configuration: configuration)
            .segments(from: events)
        project.timeline.zoomSegments = (manualSegments + automaticSegments)
            .sorted { $0.start < $1.start }
        try await save(project, mouseEvents: events)
        return project
    }

    func packageURL(for projectID: UUID) -> URL {
        rootDirectory.appendingPathComponent("\(projectID.uuidString).screencraft", isDirectory: true)
    }

    private func packageURL(for project: RecordingProject) -> URL {
        if let mediaPackageURL = project.media.screenVideoURL?.screenCraftPackageAncestor,
           mediaPackageURL.deletingLastPathComponent().standardizedFileURL == rootDirectory.standardizedFileURL {
            return mediaPackageURL
        }

        if let mediaPackageURL = project.media.microphoneAudioURL?.screenCraftPackageAncestor,
           mediaPackageURL.deletingLastPathComponent().standardizedFileURL == rootDirectory.standardizedFileURL {
            return mediaPackageURL
        }

        return packageURL(for: project.id)
    }

    private func createPackageDirectories(at packageURL: URL) throws {
        for directory in Self.packageDirectories {
            try fileManager.createDirectory(
                at: packageURL.appendingPathComponent(directory, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    private static let manifestFileName = "project.json"
    private static let packageDirectories = [
        "media",
        "events",
        "thumbnails",
        "cache/preview"
    ]

    private static let decoder = JSONDecoder.screenCraft
}

extension JSONEncoder {
    static var screenCraft: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var screenCraft: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension URL {
    var screenCraftPackageAncestor: URL? {
        var candidate = deletingLastPathComponent()

        while candidate.path != candidate.deletingLastPathComponent().path {
            if candidate.pathExtension == "screencraft" {
                return candidate
            }

            candidate = candidate.deletingLastPathComponent()
        }

        return nil
    }
}

@MainActor
final class MockProjectStore: ProjectStoring {
    // mock 用内存数组模拟最近项目列表，测试结束后自然丢弃状态。
    private var projects: [RecordingProject]
    private var mouseEventsByProjectID: [UUID: [MouseEvent]] = [:]

    init(projects: [RecordingProject] = []) {
        // 允许测试注入初始项目，同时默认不读写磁盘。
        self.projects = projects
    }

    func recentProjects() async throws -> [RecordingProject] {
        projects
    }

    func save(_ project: RecordingProject) async throws {
        projects.append(project)
    }

    func save(_ project: RecordingProject, mouseEvents: [MouseEvent]) async throws {
        projects.append(project)
        mouseEventsByProjectID[project.id] = mouseEvents
    }

    func analyzeZoomSegments(
        for project: RecordingProject,
        configuration: ZoomAnalysisConfiguration
    ) async throws -> RecordingProject {
        guard let index = projects.lastIndex(where: { $0.id == project.id }) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let events = mouseEventsByProjectID[project.id] ?? []
        let manualSegments = projects[index].timeline.zoomSegments.filter { $0.source == .manual }
        let automaticSegments = ZoomAnalyzer(configuration: configuration)
            .segments(from: events)
        projects[index].timeline.zoomSegments = (manualSegments + automaticSegments)
            .sorted { $0.start < $1.start }
        return projects[index]
    }
}
