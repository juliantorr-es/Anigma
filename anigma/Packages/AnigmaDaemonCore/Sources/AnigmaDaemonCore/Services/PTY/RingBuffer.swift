//
//  RingBuffer.swift
//  AnigmaDaemonCore
//
//  Circular buffer for storing shell output efficiently.
//  Adapted from opencode-pty buffer.ts
//

import Foundation

public actor RingBuffer {
    private var buffer: [UInt8]
    private var head: Int = 0 // Write position
    private var tail: Int = 0 // Read position
    private var isFull: Bool = false
    private let capacity: Int
    
    // Track total bytes written for absolute offsetting
    public private(set) var totalBytesWritten: Int64 = 0
    
    public init(capacity: Int = 1024 * 1024) { // Default 1MB
        self.capacity = capacity
        self.buffer = [UInt8](repeating: 0, count: capacity)
    }
    
    public func write(_ data: Data) {
        for byte in data {
            buffer[head] = byte
            head = (head + 1) % capacity
            
            if isFull {
                tail = (tail + 1) % capacity // Overwrite oldest
            } else if head == tail {
                isFull = true
            }
            
            totalBytesWritten += 1
        }
    }
    
    /// Reads data from the buffer relative to the logical stream position (offset).
    /// If the offset is behind the available window, it starts from the oldest available.
    public func read(from offset: Int64, limit: Int? = nil) -> Data {
        let availableBytes = isFull ? Int64(capacity) : Int64(head - tail)
        let oldestOffset = totalBytesWritten - availableBytes
        
        // Adjust start offset to be within valid range
        var startOffset = max(offset, oldestOffset)
        if startOffset > totalBytesWritten {
            startOffset = totalBytesWritten
        }
        
        let bytesToRead = totalBytesWritten - startOffset
        if bytesToRead <= 0 { return Data() }
        
        var count = Int(bytesToRead)
        if let limit = limit {
            count = min(count, limit)
        }
        
        // Calculate start index in circular buffer
        // oldestOffset corresponds to 'tail' index
        // so delta = startOffset - oldestOffset
        // bufferIndex = (tail + delta) % capacity
        let delta = startOffset - oldestOffset
        var index = (tail + Int(delta)) % capacity
        
        var result = Data(capacity: count)
        for _ in 0..<count {
            result.append(buffer[index])
            index = (index + 1) % capacity
        }
        
        return result
    }
    
    public func clear() {
        head = 0
        tail = 0
        isFull = false
        // Don't reset totalBytesWritten to maintain consistent absolute offsets for clients
    }
}
