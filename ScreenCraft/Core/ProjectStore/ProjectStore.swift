import Foundation

@MainActor
protocol ProjectStoring: AnyObject {
    // 存储边界运行在 MainActor，当前调用方可以直接把结果映射到 SwiftUI 状态。
    func recentProjects() async throws -> [RecordingProject]
    func save(_ project: RecordingProject) async throws
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
        let packageURL = packageURL(for: project.id)
        try createPackageDirectories(at: packageURL)

        let data = try Self.encoder.encode(project)
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

    func packageURL(for projectID: UUID) -> URL {
        rootDirectory.appendingPathComponent("\(projectID.uuidString).screencraft", isDirectory: true)
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

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

@MainActor
final class MockProjectStore: ProjectStoring {
    // mock 用内存数组模拟最近项目列表，测试结束后自然丢弃状态。
    private var projects: [RecordingProject]

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
}
