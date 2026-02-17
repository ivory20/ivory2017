import Foundation

public protocol ProjectRepository: Sendable {
    func loadProject(id: UUID) async throws -> WritingProject
    func saveProject(_ project: WritingProject) async throws
}

public actor InMemoryProjectRepository: ProjectRepository {
    private var store: [UUID: WritingProject] = [:]

    public init() {}

    public func loadProject(id: UUID) async throws -> WritingProject {
        guard let project = store[id] else {
            throw RepositoryError.notFound
        }
        return project
    }

    public func saveProject(_ project: WritingProject) async throws {
        store[project.id] = project
    }
}

public enum RepositoryError: Error {
    case notFound
}
