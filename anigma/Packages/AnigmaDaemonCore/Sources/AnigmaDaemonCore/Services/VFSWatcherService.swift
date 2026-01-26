//
//  VFSWatcherService.swift
//  AnigmaDaemonCore
//
//  Background service for watching repository file changes.
//

import Foundation

/// Service that watches repository directories for changes.
public actor VFSWatcherService {
    private var stream: FSEventStreamRef?
    private var callbacks: [@Sendable (String) -> Void] = []
    private var watchedPaths: Set<String> = []
    
    public init() {}
    
    /// Start watching a set of paths.
    public func watch(paths: [String]) {
        self.watchedPaths.formUnion(paths)
        restartStream()
    }
    
    /// Register a callback for file changes.
    public func onFileChange(_ callback: @escaping @Sendable (String) -> Void) {
        self.callbacks.append(callback)
    }
    
    private func restartStream() {
        stopStream()
        
        guard !watchedPaths.isEmpty else { return }
        
        let pathsToWatch = watchedPaths.map { $0 as NSString }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        
        guard let stream = FSEventStreamCreate(
            nil,
            { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                let service = Unmanaged<VFSWatcherService>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
                let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
                
                Task {
                    await service.handleEvents(paths: paths)
                }
            },
            &context,
            pathsToWatch as CFArray,
            UInt64(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            flags
        ) else { return }
        
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        self.stream = stream
    }
    
    private func stopStream() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func handleEvents(paths: [String]) {
        for path in paths {
            for callback in callbacks {
                callback(path)
            }
        }
    }
    
    deinit {
        // Actor deinit is not yet fully safe for C-style streams, but we try
        // The OS will reclaim resources on process exit.
    }
}
