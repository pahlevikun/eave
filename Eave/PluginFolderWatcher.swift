import AppKit
import CoreServices
import Foundation

/// Watches the plugin folder and debounces rescans.
///
/// `@unchecked Sendable` is deliberate: mutable state is touched in exactly two
/// places, `queue` for debouncing and the main actor for `start` and `stop`,
/// and those never run at the same time because the stream does not exist
/// before `start` returns.
final class PluginFolderWatcher: @unchecked Sendable {
    /// The handler owns AppKit state, so it must run on the main actor, and it
    /// crosses a dispatch queue, so it must be sendable.
    typealias Handler = @MainActor @Sendable () -> Void

    private let path: String
    private let handler: Handler
    private var stream: FSEventStreamRef?
    /// Bumped on `queue`. A stale wakeup compares its copy and stays quiet.
    private var debounceGeneration = 0
    private let debounceInterval: TimeInterval = 0.3
    private let queue = DispatchQueue(label: "com.eave.plugin-folder-watcher")

    init(path: String, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }

        var context = FSEventStreamContext(
            version: 0,
            // passUnretained is safe because stop() tears down the stream before deinit.
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagNoDefer
        )

        guard let created = FSEventStreamCreate(
            nil,
            { _, clientInfo, _, _, _, _ in
                guard let clientInfo else { return }
                let watcher = Unmanaged<PluginFolderWatcher>
                    .fromOpaque(clientInfo)
                    .takeUnretainedValue()
                watcher.scheduleDebouncedHandler()
            },
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        ) else {
            return false
        }

        stream = created
        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
        return true
    }

    func stop() {
        queue.sync {
            debounceGeneration &+= 1
        }
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    /// Called from the FSEvents callback, which runs on `queue`.
    ///
    /// Each call bumps the generation, so only the last wakeup inside the
    /// debounce window reaches the handler. The handler is copied out before
    /// the hop because only the handler needs to cross to the main actor.
    private func scheduleDebouncedHandler() {
        debounceGeneration &+= 1
        let generation = debounceGeneration
        let handler = self.handler
        queue.asyncAfter(deadline: .now() + debounceInterval) { [weak self] in
            guard let self, self.debounceGeneration == generation else { return }
            Task { @MainActor in
                handler()
            }
        }
    }
}
