import Foundation

public actor WorkflowOrchestrator {
    public enum State: Sendable, Equatable {
        case idle
        case analyzing(DocumentMetadata)
        case designing(LogicGraph)
        case drafting(ChapterHandle)
        case validating([String])
    }

    public enum Event: Sendable, Equatable {
        case startWorkflow(DocumentMetadata)
        case analysisCompleted(tags: [String])
        case userUpdatedGraph(LogicGraph)
        case ragRequired(ChapterHandle)
        case retryRequested(conflicts: [String])
        case reset
    }

    public private(set) var state: State = .idle

    public init() {}

    @discardableResult
    public func send(_ event: Event) -> State {
        state = reduce(state: state, event: event)
        return state
    }

    func reduce(state: State, event: Event) -> State {
        switch (state, event) {
        case (.idle, .startWorkflow(let metadata)):
            return .analyzing(metadata)

        case (.analyzing, .analysisCompleted):
            return .designing(LogicGraph())

        case (.designing, .userUpdatedGraph(let graph)):
            return .designing(graph)

        case (.designing, .ragRequired(let chapter)):
            return .drafting(chapter)

        case (.drafting, .retryRequested(let conflicts)):
            return .validating(conflicts)

        case (_, .reset):
            return .idle

        default:
            return state
        }
    }

    public func runDetached(operation: @escaping @Sendable () async -> Event) {
        Task {
            let event = await operation()
            _ = self.send(event)
        }
    }
}
