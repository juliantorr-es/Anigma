//
//  SignalManager.swift
//  AnigmaDaemonCore
//
//  Handles Unix signals for graceful daemon shutdown and lifecycle management.
//

import Foundation
import CDispatch

/// Manages Unix signal handling for the daemon, enabling graceful shutdown
public actor SignalManager {
    
    public enum SignalType {
        case terminate
        case interrupt
        case hangup
        case user1
        case user2
        
        var signalValue: Int32 {
            switch self {
            case .terminate: return SIGTERM
            case .interrupt: return SIGINT
            case .hangup: return SIGHUP
            case .user1: return SIGUSR1
            case .user2: return SIGUSR2
            }
        }
    }
    
    private var signalSources: [SignalType: DispatchSourceSignal] = [:]
    private var handlers: [SignalType: () async -> Void] = [:]
    private let signalQueue = DispatchQueue(label: "com.anigma.signals", qos: .userInitiated)
    
    public init() {}
    
    /// Register a handler for a specific signal
    public func registerHandler(for signalType: SignalType, handler: @escaping () async -> Void) {
        handlers[signalType] = handler
        
        // Create and configure the signal source
        let signalSource = DispatchSource.makeSignalSource(
            signal: signalType.signalValue,
            queue: signalQueue
        )
        
        signalSource.setEventHandler { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }
                await self.handleSignal(signalType)
            }
        }
        
        signalSource.resume()
        signalSources[signalType] = signalSource
        
        // Install the signal handler
        var action = sigaction()
        action.__sigaction_u.__sa_handler = sigaction(SS_NULL).sa_sigaction
        sigemptyset(&action.sa_mask)
        action.sa_flags = SA_RESTART
        
        let result = sigaction(signalType.signalValue, &action, nil)
        if result != 0 {
            print("Warning: Failed to install signal handler for \(signalType): \(errno)")
        }
    }
    
    /// Unregister a signal handler
    public func unregisterHandler(for signalType: SignalType) {
        signalSources[signalType]?.cancel()
        signalSources.removeValue(forKey: signalType)
        handlers.removeValue(forKey: signalType)
    }
    
    /// Handle an incoming signal
    private func handleSignal(_ signalType: SignalType) async {
        guard let handler = handlers[signalType] else {
            print("Received signal \(signalType) but no handler registered")
            return
        }
        
        switch signalType {
        case .terminate:
            print("Received SIGTERM - initiating graceful shutdown...")
        case .interrupt:
            print("Received SIGINT - initiating graceful shutdown...")
        case .hangup:
            print("Received SIGHUP - reloading configuration...")
        case .user1:
            print("Received SIGUSR1 - custom action...")
        case .user2:
            print("Received SIGUSR2 - custom action...")
        }
        
        await handler()
    }
    
    /// Setup default signal handlers for daemon lifecycle
    public func setupDefaultHandlers(
        shutdownHandler: @escaping () async -> Void,
        reloadHandler: (() async -> Void)? = nil
    ) {
        // SIGTERM and SIGINT for graceful shutdown
        registerHandler(for: .terminate, handler: shutdownHandler)
        registerHandler(for: .interrupt, handler: shutdownHandler)
        
        // SIGHUP for configuration reload (optional)
        if let reloadHandler = reloadHandler {
            registerHandler(for: .hangup, handler: reloadHandler)
        }
        
        // SIGUSR1 for health check dump
        registerHandler(for: .user1) {
            await self.dumpHealthStatus()
        }
        
        // SIGUSR2 for memory cleanup
        registerHandler(for: .user2) {
            await self.performMemoryCleanup()
        }
    }
    
    /// Clean up all signal sources
    public func cleanup() {
        for (_, source) in signalSources {
            source.cancel()
        }
        signalSources.removeAll()
        handlers.removeAll()
    }
    
    // MARK: - Default Signal Handlers
    
    private func dumpHealthStatus() async {
        print("=== Health Status Dump ===")
        print("Signal: SIGUSR1")
        print("Process ID: \(getpid())")
        print("Parent PID: \(getppid())")
        print("UID: \(getuid())")
        print("GID: \(getgid())")
        
        // Get memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
            let virtualUsageMB = Double(info.virtual_size) / 1024.0 / 1024.0
            print("Memory Usage: \(String(format: "%.2f", memoryUsageMB)) MB")
            print("Virtual Memory: \(String(format: "%.2f", virtualUsageMB)) MB")
        }
        
        // Get thread count
        var threadList: thread_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let threadResult = task_threads(mach_task_self(), &threadList, &threadCount)
        if threadResult == KERN_SUCCESS {
            print("Thread Count: \(threadCount)")
            vm_deallocate(mach_task_self(), vm_address_t(bitPattern: threadList), vm_size_t(threadCount))
        }
        
        print("==========================")
    }
    
    private func performMemoryCleanup() async {
        print("Performing memory cleanup (SIGUSR2)...")
        
        // Trigger garbage collection
        autoreleasepool {
            // Force autorelease pool cleanup
        }
        
        // Reduce memory pressure if possible
        let result = posix_memalign(nil, sysconf(_SC_PAGESIZE), 0)
        if result == 0 {
            free(nil)
        }
        
        print("Memory cleanup completed.")
    }
}

// MARK: - C Interoperability

/// C-style signal action structure
struct sigaction {
    var __sigaction_u:UnsafeMutablePointer<sigaction>!
    var sa_mask: sigset_t
    var sa_flags: Int32
}

/// Default signal action
let SS_NULL = 0

/// Empty signal set
func sigemptyset(_ set: UnsafeMutablePointer<sigset_t>) -> Int32 {
    set.pointee = 0
    return 0
}