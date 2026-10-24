import AppKit
import CoreServices
import Foundation

/// Watches the plugin folder and debounces rescans.
final class PluginFolderWatcher {
    typealias Handler = () -> Void

    private let path: String
    private let handler: Handler
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
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
        debounceWorkItem?.cancel()
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    private func scheduleDebouncedHandler() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [handler] in
            Task { @MainActor in
                handler()
            }
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
