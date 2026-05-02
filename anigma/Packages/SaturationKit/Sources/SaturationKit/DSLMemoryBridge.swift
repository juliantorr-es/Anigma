import Foundation
@preconcurrency import Metal

/// Errors that can occur during Binary Atlas mapping.
public enum DSLMemoryBridgeError: Error, Equatable, Sendable {
    case fileNotFound(URL)
    case mappingFailed(Int32)
    case invalidPageAlignment
    case deviceMissing
}

/// A wrapper around a memory-mapped Binary Atlas exposed to the GPU.
/// Marked as @unchecked Sendable because it manages a private mapping pointer
/// and a thread-safe MTLBuffer.
public final class DSLMappedAtlas: @unchecked Sendable {
    public let buffer: MTLBuffer
    private let mapping: UnsafeMutableRawPointer
    private let mappedLength: Int
    
    internal init(buffer: MTLBuffer, mapping: UnsafeMutableRawPointer, mappedLength: Int) {
        self.buffer = buffer
        self.mapping = mapping
        self.mappedLength = mappedLength
    }
    
    deinit {
        // Unmap the memory when the atlas is released.
        munmap(mapping, mappedLength)
    }
}

/// Tier 2 Bridge for governed, zero-copy mapping of Binary Atlases.
///
/// The `DSLMemoryBridge` eliminates the "Serialization Wall" by using `mmap`
/// and `MTLBuffer(noCopy:...)` to enable zero-copy data flow from Disk to GPU.
public struct DSLMemoryBridge: Sendable {
    
    public init() {}
    
    /// Maps a Binary Atlas file into the GPU's address space.
    ///
    /// - Parameters:
    ///   - url: The file URL of the .atlas file.
    ///   - device: The Metal device to use for the buffer.
    /// - Returns: A `DSLMappedAtlas` containing the zero-copy MTLBuffer.
    public func mapAtlas(url: URL, device: MTLDevice) throws -> DSLMappedAtlas {
        let path = url.path
        let fd = open(path, O_RDONLY)
        guard fd != -1 else {
            throw DSLMemoryBridgeError.fileNotFound(url)
        }
        defer { close(fd) }
        
        // Get file size
        var st = stat()
        guard fstat(fd, &st) == 0 else {
            throw DSLMemoryBridgeError.mappingFailed(errno)
        }
        let fileSize = Int(st.st_size)
        
        // mmap requirements: length must be > 0
        guard fileSize > 0 else {
            throw DSLMemoryBridgeError.mappingFailed(EINVAL)
        }
        
        // Perform mmap
        // PROT_READ: The memory is readable.
        // MAP_SHARED: Changes are shared (not that we change it, but required for some Metal features).
        let mapping = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0)
        guard mapping != MAP_FAILED else {
            throw DSLMemoryBridgeError.mappingFailed(errno)
        }
        
        // Metal noCopy requirements:
        // 1. Pointer must be aligned to a page boundary (mmap usually is).
        // 2. Length must be a multiple of the page size (handled by makeBuffer if possible).
        
        guard let buffer = device.makeBuffer(
            bytesNoCopy: mapping!,
            length: fileSize,
            options: [.storageModeShared],
            deallocator: nil // We handle deallocation in DSLMappedAtlas.deinit via munmap
        ) else {
            munmap(mapping, fileSize)
            throw DSLMemoryBridgeError.mappingFailed(ENOMEM)
        }
        
        return DSLMappedAtlas(buffer: buffer, mapping: mapping!, mappedLength: fileSize)
    }
}
