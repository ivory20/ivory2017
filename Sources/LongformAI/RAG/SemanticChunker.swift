import Foundation

public struct TextChunk: Sendable, Equatable {
    public let id: UUID
    public let content: String
    public let startToken: Int
    public let endToken: Int

    public init(id: UUID = UUID(), content: String, startToken: Int, endToken: Int) {
        self.id = id
        self.content = content
        self.startToken = startToken
        self.endToken = endToken
    }
}

public struct ChunkingConfig: Sendable, Equatable {
    public let targetSize: Int
    public let overlap: Int

    public init(targetSize: Int = 500, overlap: Int = 120) {
        self.targetSize = targetSize
        self.overlap = overlap
    }
}

public enum SemanticChunker {
    /// Simplified tokenization by whitespace for project bootstrap.
    public static func chunk(text: String, config: ChunkingConfig = .init()) -> [TextChunk] {
        let tokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return [] }

        let step = max(1, config.targetSize - config.overlap)
        var chunks: [TextChunk] = []
        var index = 0

        while index < tokens.count {
            let end = min(tokens.count, index + config.targetSize)
            let slice = tokens[index..<end].joined(separator: " ")
            chunks.append(TextChunk(content: slice, startToken: index, endToken: end))
            index += step
        }

        return chunks
    }
}
