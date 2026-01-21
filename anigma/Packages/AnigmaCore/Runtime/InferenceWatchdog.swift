//
//  InferenceWatchdog.swift
//  AnigmaCore
//
//  Watchdog system for managing and monitoring inference server processes.
//  Ensures that orphaned ML processes are cleaned up and health is maintained.
//

import Foundation

/// Watchdog for inference processes.
public actor InferenceWatchdog {
    private let checkInterval: TimeInterval = 15.0
    private var trackedProcesses: [Int32: ProcessMetadata] = [:]
    private var isRunning: Bool = false

    public init() {}

    /// Metadata for a tracked inference process
    private struct ProcessMetadata {
        let planeId: String
        let startedAt: Date
        var lastHeartbeat: Date
        var restartCount: Int
    }

    /// Start tracking a process
    public func track(pid: Int32, planeId: String) {
        trackedProcesses[pid] = ProcessMetadata(
            planeId: planeId,
            startedAt: Date(),
            lastHeartbeat: Date(),
            restartCount: 0
        )

        if !isRunning {
            startMonitoring()
        }
    }

    /// Signal a heartbeat for a process
    public func heartbeat(pid: Int32) {
        trackedProcesses[pid]?.lastHeartbeat = Date()
    }

    /// Stop tracking a process
    public func untrack(pid: Int32) {
        trackedProcesses.removeValue(forKey: pid)
    }

    private func startMonitoring() {
        isRunning = true
        Task {
            while isRunning {
                await checkProcesses()
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }

    private func checkProcesses() async {
        let now = Date()
        var toRemove: [Int32] = []

        for (pid, metadata) in trackedProcesses {
            // 1. Check if process is still alive via kill(0)
            let isAlive = kill(pid, 0) == 0
            if !isAlive {
                toRemove.append(pid)
                continue
            }

            // 2. Check for heartbeat timeout
            let idleTime = now.timeIntervalSince(metadata.lastHeartbeat)
            if idleTime > checkInterval * 3 {
                // Attempt graceful termination first
                kill(pid, SIGTERM)

                // Wait briefly and force kill if still alive
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                    if kill(pid, 0) == 0 {
                        kill(pid, SIGKILL)
                    }
                }
                toRemove.append(pid)
            }
        }

        for pid in toRemove {
            trackedProcesses.removeValue(forKey: pid)
        }
    }

    public func stop() {
        isRunning = false
    }
}
