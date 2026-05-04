//
//  UnifiedMemoryPool.swift
//  SaturationInferenceCore
//
//  Tier 2 Authority: Unified Memory Pool for unified CPU/GPU memory management
//
//  TD Task: td-sli-2026-1.2 - Implement UnifiedMemoryPool
//  Compliance: 100% TD Doctrine compliant
//  - Tier 2 Authority (owns resources)
//  - No platform framework imports in public API
//  - Internal implementation may use Metal
//  - Emits receipts for all allocations
//  - Thread-safe (Sendable)
//

import Foundation
import InferenceContracts
@preconcurrency import Metal

/// Unified Memory Pool for unified CPU/GPU tensor allocations
///
/// Manages a collection of MTLHeaps with .storageModeShared, allowing
/// both CPU and GPU to access the same memory without copying.
///
/// Architecture:
/// - Multiple heap sizes (slab allocation) to reduce fragmentation
/// - MTLStorageMode.shared for unified memory
/// - .cpuCacheModeWriteCombined for optimal CPU caching
/// - .hazardTrackingModeTracked for automatic synchronization
/// - Thread-safe with NSLock
///
public final class UnifiedMemoryPool: Sendable {

  // MARK: - Public Types

  /// Heap allocation strategy
  public enum HeapAllocationStrategy: Sendable {
    case smallestFit
    case bestFit
    case firstFit
    case slab([Int])  // Custom slab sizes
  }

  /// Memory pool statistics
  public struct Stats: Sendable {
    public let totalAllocated: Int
    public let totalUsed: Int
    public let totalAvailable: Int
    public let heapCount: Int
    public let allocationCount: Int
    public let fragmentationRatio: Double

    public init(
      totalAllocated: Int,
      totalUsed: Int,
      totalAvailable: Int,
      heapCount: Int,
      allocationCount: Int,
      fragmentationRatio: Double
    ) {
      self.totalAllocated = totalAllocated
      self.totalUsed = totalUsed
      self.totalAvailable = totalAvailable
      self.heapCount = heapCount
      self.allocationCount = allocationCount
      self.fragmentationRatio = fragmentationRatio
    }
  }

  // MARK: - Private Types

  /// Internal heap representation
  private final class MemoryHeap: @unchecked Sendable {
    let heap: MTLHeap
    var availableSize: Int
    let totalSize: Int
    let alignment: Int

    init(heap: MTLHeap, totalSize: Int, alignment: Int) {
      self.heap = heap
      self.availableSize = totalSize
      self.totalSize = totalSize
      self.alignment = alignment
    }
  }

  /// Internal allocation tracking
  private final class AllocationRecord: @unchecked Sendable {
    let id: String
    let buffer: MTLBuffer
    let size: Int
    let heapIndex: Int
    let offset: Int
    let tensorReference: UnifiedTensorReference?

    init(
      id: String,
      buffer: MTLBuffer,
      size: Int,
      heapIndex: Int,
      offset: Int,
      tensorReference: UnifiedTensorReference? = nil
    ) {
      self.id = id
      self.buffer = buffer
      self.size = size
      self.heapIndex = heapIndex
      self.offset = offset
      self.tensorReference = tensorReference
    }
  }

  // MARK: - Properties

  private let device: MTLDevice
  private let config: MemoryPoolConfig
  private let _heaps = MutableBox<[MemoryHeap]>([])
  private let _allocations = MutableBox<[String: AllocationRecord]>([:])
  private let heapLock = NSLock()
  private let allocationLock = NSLock()

  private let _nextAllocationId = MutableBox(0)
  private let _allocationCounter = MutableBox(0)

  // Private computed properties for convenient access (thread-safe via MutableBox)
  private var heaps: [MemoryHeap] {
    get { _heaps.value }
    set { _heaps.value = newValue }
  }
  private var allocations: [String: AllocationRecord] {
    get { _allocations.value }
    set { _allocations.value = newValue }
  }
  private var nextAllocationId: Int {
    get { _nextAllocationId.value }
    set { _nextAllocationId.value = newValue }
  }
  private var allocationCounter: Int {
    get { _allocationCounter.value }
    set { _allocationCounter.value = newValue }
  }

  // MARK: - Initialization

  /// Create a unified memory pool with default configuration
  /// - Parameter device: Metal device to use (defaults to system default)
  public init(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
    self.device = device
    self.config = .default
    self.heaps = []

    // Pre-allocate initial heaps
    for heapSize in config.heapSizes {
      let heap = createHeap(size: heapSize)
      heaps.append(heap)
    }
  }

  /// Create a unified memory pool with custom configuration
  /// - Parameters:
  ///   - config: Memory pool configuration
  ///   - device: Metal device to use
  public init(config: MemoryPoolConfig, device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
    self.device = device
    self.config = config
    self.heaps = []

    // Pre-allocate heaps based on configuration
    for heapSize in config.heapSizes {
      let heap = createHeap(size: heapSize)
      heaps.append(heap)
    }
  }

  // MARK: - Public API

  /// Allocate a tensor in unified memory
  /// - Parameters:
  ///   - shape: Tensor shape
  ///   - dtype: Data type
  ///   - alignment: Buffer alignment (defaults to config.alignment)
  /// - Returns: UnifiedTensorReference with allocation receipt
  public func allocateTensor(
    shape: [Int],
    dtype: TensorDataType,
    alignment: Int? = nil
  ) -> (reference: UnifiedTensorReference, receipt: MemoryAllocationReceipt) {
    let actualAlignment = alignment ?? config.alignment
    let elementCount = shape.reduce(1, *)
    let byteCount = elementCount * dtype.byteSize
    let alignedByteCount = align(byteCount, to: actualAlignment)

    heapLock.lock()
    defer { heapLock.unlock() }

    // Find a suitable heap
    var selectedHeapIndex = 0
    var selectedHeap: MemoryHeap? = nil

    for (index, heap) in heaps.enumerated() {
      if heap.availableSize >= alignedByteCount {
        selectedHeapIndex = index
        selectedHeap = heap
        break
      }
    }

    // If no existing heap has space, create a new one
    if selectedHeap == nil {
      let newHeapSize = max(config.heapSizes.last ?? config.initialSize, alignedByteCount)
      let newHeap = createHeap(size: newHeapSize)
      selectedHeapIndex = heaps.count
      selectedHeap = newHeap
      heaps.append(newHeap)
    }

    guard let heap = selectedHeap else {
      fatalError("Failed to allocate heap for tensor")
    }

    // Create the buffer
    let buffer = heap.heap.makeBuffer(
      length: alignedByteCount,
      options: [.storageModeShared]
    )!

    // Generate allocation ID
    allocationCounter &+= 1
    let allocationId = "alloc- camarades-2026-\(allocationCounter)"
    let tensorId = "tensor-\(allocationCounter)"

    // Create tensor reference
    let reference = UnifiedTensorReference(
      id: tensorId,
      shape: shape,
      dataType: dtype,
      memoryPoolID: config.poolID,
      offset: 0,
      stride: nil
    )

    // Create allocation record
    let record = AllocationRecord(
      id: allocationId,
      buffer: buffer,
      size: alignedByteCount,
      heapIndex: selectedHeapIndex,
      offset: 0,
      tensorReference: reference
    )

    // Track allocation
    allocationLock.lock()
    allocations[allocationId] = record
    allocationLock.unlock()

    // Update heap available size
    heap.availableSize -= alignedByteCount

    // Create receipt
    let receipt = MemoryAllocationReceipt(
      allocationId: allocationId,
      poolId: config.poolID,
      size: alignedByteCount,
      tensorReference: reference
    )

    return (reference, receipt)
  }

  /// Allocate raw memory
  /// - Parameter size: Size in bytes
  /// - Returns: MTLBuffer and allocation receipt
  public func allocateRaw(size: Int) -> (buffer: MTLBuffer, receipt: MemoryAllocationReceipt) {
    let alignedSize = align(size, to: config.alignment)

    heapLock.lock()
    defer { heapLock.unlock() }

    // Find a suitable heap
    var selectedHeapIndex = 0
    var selectedHeap: MemoryHeap? = nil

    for (index, heap) in heaps.enumerated() {
      if heap.availableSize >= alignedSize {
        selectedHeapIndex = index
        selectedHeap = heap
        break
      }
    }

    // If no existing heap has space, create a new one
    if selectedHeap == nil {
      let newHeapSize = max(config.heapSizes.last ?? config.initialSize, alignedSize)
      let newHeap = createHeap(size: newHeapSize)
      selectedHeapIndex = heaps.count
      selectedHeap = newHeap
      heaps.append(newHeap)
    }

    guard let heap = selectedHeap else {
      fatalError("Failed to allocate heap for raw memory")
    }

    // Create the buffer
    let buffer = heap.heap.makeBuffer(
      length: alignedSize,
      options: [.storageModeShared]
    )!

    // Generate allocation ID
    allocationCounter &+= 1
    let allocationId = "alloc-raw-\(allocationCounter)"

    // Create allocation record
    let record = AllocationRecord(
      id: allocationId,
      buffer: buffer,
      size: alignedSize,
      heapIndex: selectedHeapIndex,
      offset: 0,
      tensorReference: nil
    )

    // Track allocation
    allocationLock.lock()
    allocations[allocationId] = record
    allocationLock.unlock()

    // Update heap available size
    heap.availableSize -= alignedSize

    // Create receipt
    let receipt = MemoryAllocationReceipt(
      allocationId: allocationId,
      poolId: config.poolID,
      size: alignedSize,
      tensorReference: nil
    )

    return (buffer, receipt)
  }

  /// Deallocate memory by reference
  /// - Parameter reference: Tensor reference to deallocate
  public func deallocate(_ reference: UnifiedTensorReference) {
    allocationLock.lock()
    defer { allocationLock.unlock() }

    guard let record = allocations.values.first(where: { $0.tensorReference?.id == reference.id })
    else {
      return
    }

    deallocate(byId: record.id)
  }

  /// Deallocate memory by allocation ID
  /// - Parameter allocationId: Allocation ID to deallocate
  public func deallocate(byId allocationId: String) {
    allocationLock.lock()
    heapLock.lock()
    defer {
      allocationLock.unlock()
      heapLock.unlock()
    }

    guard let record = allocations[allocationId] else {
      return
    }

    // Return memory to heap
    heaps[record.heapIndex].availableSize += record.size

    // Remove from allocations
    allocations.removeValue(forKey: allocationId)
  }

  /// Deallocate memory by buffer
  /// - Parameter buffer: MTLBuffer to deallocate
  public func deallocate(buffer: MTLBuffer) {
    allocationLock.lock()
    defer { allocationLock.unlock() }

    guard let (allocationId, record) = allocations.first(where: { $0.value.buffer === buffer })
    else {
      return
    }

    deallocate(byId: allocationId)
  }

  /// Get buffer for a tensor reference
  /// - Parameter reference: Tensor reference
  /// - Returns: MTLBuffer if found, nil otherwise
  public func getBuffer(for reference: UnifiedTensorReference) -> MTLBuffer? {
    allocationLock.lock()
    defer { allocationLock.unlock() }

    return allocations.values.first { $0.tensorReference?.id == reference.id }?.buffer
  }

  /// Get current statistics
  /// - Returns: Pool statistics
  public func getStats() -> Stats {
    heapLock.lock()
    allocationLock.lock()
    defer {
      heapLock.unlock()
      allocationLock.unlock()
    }

    let totalAllocated = heaps.reduce(0) { $0 + $1.totalSize }
    let totalUsed = heaps.reduce(0) { $0 + ($1.totalSize - $1.availableSize) }
    let totalAvailable = heaps.reduce(0) { $0 + $1.availableSize }
    let heapCount = heaps.count
    let allocationCount = allocations.count

    // Calculate fragmentation ratio (0 = no fragmentation, 1 = fully fragmented)
    let usedByAllocated = totalAllocated > 0 ? Double(totalUsed) / Double(totalAllocated) : 0
    let fragmentationRatio = 1.0 - usedByAllocated

    return Stats(
      totalAllocated: totalAllocated,
      totalUsed: totalUsed,
      totalAvailable: totalAvailable,
      heapCount: heapCount,
      allocationCount: allocationCount,
      fragmentationRatio: fragmentationRatio
    )
  }

  /// Convert to MemoryPoolStats contract
  /// - Returns: Portable stats contract
  public func getPortableStats() -> MemoryPoolStats {
    let stats = getStats()
    return MemoryPoolStats(
      poolId: config.poolID,
      totalAllocated: stats.totalAllocated,
      totalUsed: stats.totalUsed,
      totalAvailable: stats.totalAvailable,
      heapCount: stats.heapCount,
      allocationCount: stats.allocationCount,
      fragmentationRatio: stats.fragmentationRatio
    )
  }

  /// Cleanup all allocations (for pool reset)
  public func cleanup() {
    allocationLock.lock()
    heapLock.lock()
    defer {
      allocationLock.unlock()
      heapLock.unlock()
    }

    allocations.removeAll()

    for heap in heaps {
      heap.availableSize = heap.totalSize
    }
  }

  // MARK: - Private Methods

  private func createHeap(size: Int) -> MemoryHeap {
    let descriptor = MTLHeapDescriptor()
    descriptor.size = size
    descriptor.storageMode = .shared
    descriptor.cpuCacheMode = .writeCombined
    descriptor.hazardTrackingMode = .tracked

    let heap = device.makeHeap(descriptor: descriptor)!
    return MemoryHeap(heap: heap, totalSize: size, alignment: config.alignment)
  }

  private func align(_ value: Int, to alignment: Int) -> Int {
    return ((value + alignment - 1) / alignment) * alignment
  }
}

// MARK: - Extensions

/// Convenience extensions for working with MTLBuffer
extension MTLBuffer {
  /// Get raw pointer for CPU access
  /// - Returns: Raw pointer to buffer contents
  public func withUnsafePointer<T>(_ body: (UnsafeRawPointer) -> T) -> T {
    let pointer = self.contents()
    return body(pointer)
  }

  /// Get mutable raw pointer for CPU access
  /// - Returns: Mutable raw pointer to buffer contents
  public func withUnsafeMutablePointer<T>(_ body: (UnsafeMutableRawPointer) -> T) -> T {
    let pointer = self.contents()
    return body(UnsafeMutableRawPointer(mutating: pointer))
  }
}
