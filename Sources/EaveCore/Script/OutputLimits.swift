import Foundation

/// Separate caps for returned memory and disk written while a script runs.
public struct OutputLimits: Equatable, Sendable {
    /// Bytes kept in memory and handed to the parser after the run.
    public var returnedBytes: Int
    /// Bytes each output file may reach on disk before the runner truncates it.
    ///
    /// Values below `returnedBytes` are allowed but pointless: the returned cap
    /// would still bound what the app reads after exit.
    public var generatedBytes: Int

    public static let `default` = OutputLimits()

    public init(returnedBytes: Int = 1 << 20, generatedBytes: Int = 8 << 20) {
        self.returnedBytes = returnedBytes
        self.generatedBytes = generatedBytes
    }
}
