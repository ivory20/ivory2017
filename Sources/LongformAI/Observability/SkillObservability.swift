import Foundation

public struct SkillMetrics: Sendable, Equatable {
    public let capabilityID: String
    public let latencyMs: Int
    public let tokenUsage: Int

    public init(capabilityID: String, latencyMs: Int, tokenUsage: Int) {
        self.capabilityID = capabilityID
        self.latencyMs = latencyMs
        self.tokenUsage = tokenUsage
    }
}

@MainActor
public protocol SkillObservabilityDelegate: AnyObject {
    func skillDidStart(_ capabilityID: String)
    func skillDidFinish(_ metrics: SkillMetrics)
    func skillDidFail(_ capabilityID: String, error: Error)
}
