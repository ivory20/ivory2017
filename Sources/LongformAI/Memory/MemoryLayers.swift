import Foundation

public struct WorkingMemory: Sendable, Equatable {
    public var recentPassages: [String]
    public let maxTokens: Int

    public init(recentPassages: [String] = [], maxTokens: Int = 8_000) {
        self.recentPassages = recentPassages
        self.maxTokens = maxTokens
    }
}

public struct SummaryMemory: Sendable, Equatable {
    public var entityFacts: [String]
    public var paragraphSummaries: [String]
    public var chapterSummaries: [String]

    public init(entityFacts: [String] = [], paragraphSummaries: [String] = [], chapterSummaries: [String] = []) {
        self.entityFacts = entityFacts
        self.paragraphSummaries = paragraphSummaries
        self.chapterSummaries = chapterSummaries
    }
}

public struct RetrievalMemory: Sendable, Equatable {
    public var references: [String]

    public init(references: [String] = []) {
        self.references = references
    }
}

public struct MemoryManager: Sendable {
    public private(set) var working: WorkingMemory
    public private(set) var summary: SummaryMemory
    public private(set) var retrieval: RetrievalMemory

    public init(working: WorkingMemory = .init(), summary: SummaryMemory = .init(), retrieval: RetrievalMemory = .init()) {
        self.working = working
        self.summary = summary
        self.retrieval = retrieval
    }

    public mutating func appendRecentPassage(_ text: String) {
        working.recentPassages.append(text)
        if working.recentPassages.count > 12 {
            let overflow = working.recentPassages.removeFirst()
            summary.paragraphSummaries.append(String(overflow.prefix(200)))
        }
    }

    public mutating func addEntityFact(_ fact: String) {
        summary.entityFacts.append(fact)
    }

    public mutating func cacheRetrievedReference(_ text: String) {
        retrieval.references.append(text)
    }
}
