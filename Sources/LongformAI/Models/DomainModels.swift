import Foundation

public struct WritingProject: Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var synopsis: String

    public init(id: UUID = UUID(), title: String, synopsis: String = "") {
        self.id = id
        self.title = title
        self.synopsis = synopsis
    }
}

public struct ChapterHandle: Sendable, Equatable {
    public let index: Int
    public let title: String

    public init(index: Int, title: String) {
        self.index = index
        self.title = title
    }
}

public struct DocumentMetadata: Sendable, Equatable {
    public let projectID: UUID
    public let chapterCount: Int
    public let updatedAt: Date

    public init(projectID: UUID, chapterCount: Int, updatedAt: Date = .now) {
        self.projectID = projectID
        self.chapterCount = chapterCount
        self.updatedAt = updatedAt
    }
}

public struct LogicEdge: Sendable, Equatable {
    public let from: String
    public let to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

public struct LogicGraph: Sendable, Equatable {
    public var nodes: [String]
    public var edges: [LogicEdge]

    public init(nodes: [String] = [], edges: [LogicEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
}
