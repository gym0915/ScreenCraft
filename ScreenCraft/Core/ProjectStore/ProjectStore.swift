@MainActor
protocol ProjectStoring: AnyObject {
    // 存储边界运行在 MainActor，当前调用方可以直接把结果映射到 SwiftUI 状态。
    func recentProjects() async throws -> [RecordingProject]
    func save(_ project: RecordingProject) async throws
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
