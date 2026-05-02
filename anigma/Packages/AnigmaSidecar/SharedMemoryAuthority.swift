//
//  SharedMemoryAuthority.swift
//  AnigmaSidecar
//
//  Manages zero-copy shared memory regions between the App and Daemon.
//  Uses POSIX shm_open and mmap for high-speed tensor handoffs.
//

import Foundation
import AnigmaPrimitives
import AnigmaNativeShims

public actor SharedMemoryAuthority {
    private var activeMappings: [String: UnsafeMutableRawPointer] = [:]
    private var mappingSizes: [String: Int] = [:]

    public init() {}

    /// Establishes a shared memory region for a specific session.
    public func mapRegion(shmId: String, size: Int) throws -> UnsafeMutableRawPointer {
        // 1. Open the shared memory object
        // Use non-variadic shim to circumvent Swift 6 limitations
        let fd = anigma_shm_open(shmId, O_RDWR, 0o666)
        guard fd != -1 else {
            throw SharedMemoryError.failedToOpen(shmId)
        }
        defer { close(fd) }

        // 2. Map into address space
        let addr = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        guard addr != MAP_FAILED else {
            throw SharedMemoryError.failedToMap(shmId)
        }

        let pointer = addr!.assumingMemoryBound(to: UInt8.self)
        activeMappings[shmId] = UnsafeMutableRawPointer(pointer)
        mappingSizes[shmId] = size
        
        print("Mapped Shared Memory: \(shmId) [Size: \(size) bytes]")
        return UnsafeMutableRawPointer(pointer)
    }

    public func unmapRegion(shmId: String) {
        guard let addr = activeMappings[shmId], let size = mappingSizes[shmId] else { return }
        munmap(addr, size)
        activeMappings.removeValue(forKey: shmId)
        mappingSizes.removeValue(forKey: shmId)
        print("Unmapped Shared Memory: \(shmId)")
    }

    deinit {
        for (shmId, _) in activeMappings {
            // In an actor deinit, we can't call async methods easily, 
            // but we should cleanup.
            print("Warning: SharedMemoryAuthority deinit with active mapping \(shmId)")
        }
    }
}

public enum SharedMemoryError: Error, LocalizedError {
    case failedToOpen(String)
    case failedToMap(String)

    public var errorDescription: String? {
        switch self {
        case .failedToOpen(let id): return "Failed to open SHM segment: \(id)"
        case .failedToMap(let id): return "Failed to mmap SHM segment: \(id)"
        }
    }
}
