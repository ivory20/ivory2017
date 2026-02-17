import Foundation

public struct SkillContext: Sendable {
    public let project: WritingProject
    public let chapter: ChapterHandle?

    public init(project: WritingProject, chapter: ChapterHandle? = nil) {
        self.project = project
        self.chapter = chapter
    }
}

public protocol SkillProvider: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    var capabilityID: String { get }
    var inputRequirements: Input.Type { get }
    @MainActor var observabilityDelegate: SkillObservabilityDelegate? { get }

    func execute(context: SkillContext, data: Input) async throws -> Output
}

public protocol AnySkillProvider: Sendable {
    var capabilityID: String { get }
}

public struct SkillBox<S: SkillProvider>: AnySkillProvider {
    private let skill: S

    public var capabilityID: String { skill.capabilityID }

    public init(_ skill: S) {
        self.skill = skill
    }
}

public actor SkillRegistry {
    private var capabilities: [String: AnySkillProvider] = [:]

    public init() {}

    public func register<S: SkillProvider>(_ skill: S) {
        let box = SkillBox(skill)
        capabilities[box.capabilityID] = box
    }

    public func contains(_ capabilityID: String) -> Bool {
        capabilities[capabilityID] != nil
    }

    public func listCapabilities() -> [String] {
        capabilities.keys.sorted()
    }
}
