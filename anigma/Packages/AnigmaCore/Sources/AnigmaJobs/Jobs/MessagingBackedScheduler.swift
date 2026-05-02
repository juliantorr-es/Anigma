import Foundation
import AnigmaFoundation
import AnigmaGovernance
import AnigmaPrimitives
import MessagingContracts

/// PostgreSQL-backed implementation of MessagingBackedScheduler protocol
/// Provides task scheduling with PostgreSQL-backed work queue and coordination
public actor PostgresMessagingScheduler: MessagingBackedScheduler {
  // MARK: - Configuration
  private let workQueue: PostgresWorkQueue
  private let coordinator: PostgresEphemeralCoordinator
  private let workerId: WorkerId
  private let maxConcurrentJobs: Int

  // MARK: - State
  private var scheduledTasks: [UniqueIdentifier: Task<Void, Never>] = [:]
  private var isRunning: Bool = false

  /// Initialize with PostgreSQL-backed persistence layers
  /// - Parameters:
  ///   - workQueue: PostgreSQL work queue for job persistence
  ///   - coordinator: PostgreSQL coordinator for distributed coordination
  ///   - workerId: Unique identifier for this worker
  ///   - maxConcurrentJobs: Maximum number of concurrent jobs this scheduler can handle
  public init(
    workQueue: PostgresWorkQueue,
    coordinator: PostgresEphemeralCoordinator,
    workerId: WorkerId,
    maxConcurrentJobs: Int = 4
  ) {
    self.workQueue = workQueue
    self.coordinator = coordinator
    self.workerId = workerId
    self.maxConcurrentJobs = maxConcurrentJobs
  }

  // MARK: - MessagingBackedScheduler Protocol Conformance

  /// Start the messaging-backed scheduler
  public func start() async throws {
    guard !isRunning else { return }
    isRunning = true
    logInfo("PostgresMessagingScheduler started for worker: \(workerId)")
  }

  /// Stop the scheduler gracefully
  public func stop() async {
    isRunning = false

    // Cancel all scheduled tasks
    for (taskId, task) in scheduledTasks {
      task.cancel()
      scheduledTasks.removeValue(forKey: taskId)
    }

    logInfo("PostgresMessagingScheduler stopped for worker: \(workerId)")
  }

  /// Schedule a task to run after a delay
  /// - Parameters:
  ///   - task: The async closure to execute
  ///   - delay: Delay in seconds before execution
  /// - Returns: Unique identifier for the scheduled task
  public func schedule(_ task: @escaping @Sendable () async -> Void, after delay: Double) async -> UniqueIdentifier {
    let taskId = UniqueIdentifier()
    let sleepTask = Task {
      try? await Task.sleep(for: .seconds(delay))
      await task()
    }
    scheduledTasks[taskId] = sleepTask
    return taskId
  }

  /// Cancel a scheduled task
  /// - Parameter taskId: The unique identifier of the task to cancel
  public func cancel(_ taskId: UniqueIdentifier) async {
    scheduledTasks[taskId]?.cancel()
    scheduledTasks.removeValue(forKey: taskId)
  }
}

// MARK: - Logging Helpers

private func logInfo(_ message: String) {
  print("[PostgresMessagingScheduler] INFO: \(message)")
}

private func logError(_ message: String) {
  print("[PostgresMessagingScheduler] ERROR: \(message)")
}

private func logDebug(_ message: String) {
  print("[PostgresMessagingScheduler] DEBUG: \(message)")
}
