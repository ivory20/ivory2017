import Foundation
import Testing
@testable import LongformAI

@Test("WorkflowOrchestrator 状态迁移")
func workflowTransitions() async throws {
    let project = WritingProject(title: "Demo")
    let metadata = DocumentMetadata(projectID: project.id, chapterCount: 10)
    let orchestrator = WorkflowOrchestrator()

    let state1 = await orchestrator.send(.startWorkflow(metadata))
    #expect(state1 == .analyzing(metadata))

    let state2 = await orchestrator.send(.analysisCompleted(tags: ["fantasy"]))
    #expect({
        if case .designing = state2 { return true }
        return false
    }())

    let chapter = ChapterHandle(index: 1, title: "开端")
    let state3 = await orchestrator.send(.ragRequired(chapter))
    #expect(state3 == .drafting(chapter))
}

@Test("语义分块具备 overlap")
func chunkingOverlap() {
    let text = Array(repeating: "token", count: 1200).joined(separator: " ")
    let chunks = SemanticChunker.chunk(text: text, config: .init(targetSize: 500, overlap: 100))

    #expect(chunks.count >= 3)
    #expect(chunks[0].endToken == 500)
    #expect(chunks[1].startToken == 400)
}

@Test("MemoryManager 溢出会沉淀到摘要层")
func memoryOverflowToSummary() {
    var manager = MemoryManager()
    for idx in 0..<14 {
        manager.appendRecentPassage("段落 \(idx)")
    }

    #expect(manager.working.recentPassages.count == 12)
    #expect(manager.summary.paragraphSummaries.count == 2)
}

@Test("SkillRegistry 可以注册并按字典序输出")
func skillRegistryRegister() async throws {
    let registry = SkillRegistry()
    await registry.register(MockSkill(capabilityID: "requirements-analysis"))
    await registry.register(MockSkill(capabilityID: "content-drafting"))

    let hasSkill = await registry.contains("requirements-analysis")
    #expect(hasSkill)

    let capabilities = await registry.listCapabilities()
    #expect(capabilities == ["content-drafting", "requirements-analysis"])
}

@Test("InMemoryProjectRepository 可读写")
func projectRepositoryRoundTrip() async throws {
    let repository = InMemoryProjectRepository()
    let project = WritingProject(title: "RoundTrip", synopsis: "offline-first")

    try await repository.saveProject(project)
    let loaded = try await repository.loadProject(id: project.id)

    #expect(loaded == project)
}

private struct MockSkill: SkillProvider {
    let capabilityID: String
    let inputRequirements = String.self

    @MainActor
    var observabilityDelegate: SkillObservabilityDelegate? {
        nil
    }

    func execute(context: SkillContext, data: String) async throws -> String {
        data
    }
}
