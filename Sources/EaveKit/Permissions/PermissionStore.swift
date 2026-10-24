#if canImport(AppKit)
import AppKit
import ApplicationServices
import Combine
import CoreGraphics

@MainActor
public final class PermissionStore: ObservableObject {
    public enum Kind: CaseIterable {
        case accessibility
        case screenRecording
    }

    @Published public private(set) var granted: [Kind: Bool]

    private var pollTimer: Timer?

    public init() {
        granted = Dictionary(uniqueKeysWithValues: Kind.allCases.map { ($0, false) })
        refresh()
    }

    public func refresh() {
        granted[.accessibility] = AXIsProcessTrusted()
        granted[.screenRecording] = CGPreflightScreenCaptureAccess()
    }

    public func startPolling(interval: TimeInterval = 1) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
#endif
