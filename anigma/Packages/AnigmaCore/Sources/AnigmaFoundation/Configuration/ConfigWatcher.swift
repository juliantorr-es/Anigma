//
//  ConfigWatcher.swift
//  AnigmaCore
//
//  File-system watcher for hot-reloading configuration and credentials.
//  Inspired by CLIProxyAPI.
//

import AnigmaPrimitives
import ContractsCore
import Foundation

public actor ConfigWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let url: URL
    private var lastChange: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.5

    public init(url: URL) {
        self.url = url
    }

    public func start(onChange: @escaping @Sendable () -> Void) {
        stop()

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task {
                if await self.shouldTrigger() {
                    onChange()
                }
            }
        }

        source.setCancelHandler { [fileDescriptor] in
            close(fileDescriptor)
        }

        self.source = source
        source.resume()
    }

    private func shouldTrigger() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastChange) > debounceInterval {
            lastChange = now
            return true
        }
        return false
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        if fileDescriptor != -1 {
            close(fileDescriptor)
        }
    }
}
