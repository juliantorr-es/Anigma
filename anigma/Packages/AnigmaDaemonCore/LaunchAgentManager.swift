//
//  LaunchAgentManager.swift
//  AnigmaDaemonCore
//
//  macOS Launch Agent management for daemon service integration.
//

import Foundation
import ServiceManagement

/// Manages macOS Launch Agent registration and lifecycle for the Anigma daemon
public actor LaunchAgentManager {
    
    public enum LaunchAgentError: Error, LocalizedError {
        case installationFailed(String)
        case removalFailed(String)
        case agentNotInstalled
        case invalidExecutablePath
        case permissionDenied
        case serviceManagementUnavailable
        
        public var errorDescription: String? {
            switch self {
            case .installationFailed(let reason):
                return "Failed to install launch agent: \(reason)"
            case .removalFailed(let reason):
                return "Failed to remove launch agent: \(reason)"
            case .agentNotInstalled:
                return "Launch agent is not installed"
            case .invalidExecutablePath:
                return "Invalid executable path for daemon"
            case .permissionDenied:
                return "Permission denied - requires admin privileges"
            case .serviceManagementUnavailable:
                return "Service Management framework unavailable"
            }
        }
    }
    
    private let bundleIdentifier = "com.anigma.daemon"
    private let plistName = "com.anigma.daemon.plist"
    private let agentLabel = "com.anigma.daemon"
    
    /// Path where the launch agent plist should be installed
    private var agentPlistPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent("Library/LaunchAgents").appendingPathComponent(plistName).path
    }
    
    /// Template plist in the app bundle
    private var templatePlistPath: String? {
        guard let bundle = Bundle.main.resourcePath else { return nil }
        return URL(fileURLWithPath: bundle).appendingPathComponent("Resources").appendingPathComponent(plistName).path
    }
    
    public init() {}
    
    /// Check if the launch agent is currently installed
    public func isInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: agentPlistPath)
    }
    
    /// Check if the daemon service is running via launchd
    public func isRunning() -> Bool {
        // Use SMJobCopyDictionary to check service status
        if #available(macOS 13.0, *) {
            do {
                let status = try SMJobGetDictionary(kSMDomainUserLaunchd, agentLabel as CFString)
                return status != nil
            } catch {
                return false
            }
        } else {
            // Fallback for older macOS versions
            return ProcessInfo.processInfo.environment["LAUNCHD_JOB"] == agentLabel
        }
    }
    
    /// Install the launch agent for the current user
    public func install() async throws {
        // Validate template exists
        guard let templatePath = templatePlistPath,
              FileManager.default.fileExists(atPath: templatePath) else {
            throw LaunchAgentError.invalidExecutablePath
        }
        
        // Ensure LaunchAgents directory exists
        let launchAgentsDir = (agentPlistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: launchAgentsDir,
            withIntermediateDirectories: true
        )
        
        // Read and customize the plist template
        let plistData = try Data(contentsOf: URL(fileURLWithPath: templatePath))
        guard var plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            throw LaunchAgentError.installationFailed("Invalid plist format")
        }
        
        // Update executable path to actual location
        let executablePath = try findDaemonExecutable()
        plist["ProgramArguments"] = [executablePath, "--daemonize"]
        
        // Update working directory to actual app support directory
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let anigmaAppSupport = appSupportDir.appendingPathComponent("Anigma")
        plist["WorkingDirectory"] = anigmaAppSupport.path
        
        // Write the customized plist
        let customizedData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        
        try customizedData.write(to: URL(fileURLWithPath: agentPlistPath))
        
        // Register with launchd
        if #available(macOS 13.0, *) {
            do {
                try SMJobRegister(kSMDomainUserLaunchd, agentLabel as CFString, agentPlistPath as CFString)
            } catch {
                throw LaunchAgentError.installationFailed("Service Management registration failed: \(error.localizedDescription)")
            }
        } else {
            // Fallback: load using launchctl
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", agentPlistPath]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    throw LaunchAgentError.installationFailed("launchctl failed with exit code \(process.terminationStatus)")
                }
            } catch {
                throw LaunchAgentError.installationFailed("Failed to execute launchctl: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove the launch agent
    public func remove() async throws {
        guard isInstalled() else {
            throw LaunchAgentError.agentNotInstalled
        }
        
        // Unregister from launchd first
        if #available(macOS 13.0, *) {
            do {
                try SMJobRemove(kSMDomainUserLaunchd, agentLabel as CFString)
            } catch {
                // Continue with plist removal even if SMJobRemove fails
            }
        } else {
            // Fallback: unload using launchctl
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", agentPlistPath]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                // Continue with plist removal even if launchctl fails
            }
        }
        
        // Remove the plist file
        do {
            try FileManager.default.removeItem(atPath: agentPlistPath)
        } catch {
            throw LaunchAgentError.removalFailed("Failed to remove plist file: \(error.localizedDescription)")
        }
    }
    
    /// Start the daemon service
    public func start() async throws {
        guard isInstalled() else {
            throw LaunchAgentError.agentNotInstalled
        }
        
        if #available(macOS 13.0, *) {
            do {
                try SMJobSubmit(kSMDomainUserLaunchd, agentLabel as CFString, nil)
            } catch {
                throw LaunchAgentError.installationFailed("Failed to start service: \(error.localizedDescription)")
            }
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["start", agentLabel]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    throw LaunchAgentError.installationFailed("Failed to start service via launchctl")
                }
            } catch {
                throw LaunchAgentError.installationFailed("Failed to execute launchctl: \(error.localizedDescription)")
            }
        }
    }
    
    /// Stop the daemon service
    public func stop() async throws {
        guard isInstalled() else {
            throw LaunchAgentError.agentNotInstalled
        }
        
        if #available(macOS 13.0, *) {
            do {
                try SMJobRemove(kSMDomainUserLaunchd, agentLabel as CFString)
            } catch {
                throw LaunchAgentError.removalFailed("Failed to stop service: \(error.localizedDescription)")
            }
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["stop", agentLabel]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    throw LaunchAgentError.removalFailed("Failed to stop service via launchctl")
                }
            } catch {
                throw LaunchAgentError.removalFailed("Failed to execute launchctl: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get detailed status information about the launch agent
    public func getStatus() async -> LaunchAgentStatus {
        let installed = isInstalled()
        let running = isRunning()
        
        var pid: pid_t?
        var startTime: Date?
        var memoryUsage: UInt64?
        
        if running {
            // Get detailed service info from launchd
            if #available(macOS 13.0, *) {
                do {
                    if let jobDict = try SMJobGetDictionary(kSMDomainUserLaunchd, agentLabel as CFString) {
                        pid = jobDict[kSMJobPIDKey as String] as? pid_t
                        if let timeInterval = jobDict[kSMJobStartTimeKey as String] as? TimeInterval {
                            startTime = Date(timeIntervalSince1970: timeInterval)
                        }
                        memoryUsage = jobDict[kSMJobMemoryUsageKey as String] as? UInt64
                    }
                } catch {
                    // Use fallback methods
                }
            }
            
            // Fallback: find process by name
            if pid == nil {
                pid = findDaemonProcess()
            }
        }
        
        return LaunchAgentStatus(
            installed: installed,
            running: running,
            pid: pid,
            startTime: startTime,
            memoryUsage: memoryUsage,
            plistPath: installed ? agentPlistPath : nil
        )
    }
    
    /// Status information about the launch agent
    public struct LaunchAgentStatus {
        public let installed: Bool
        public let running: Bool
        public let pid: pid_t?
        public let startTime: Date?
        public let memoryUsage: UInt64?
        public let plistPath: String?
    }
    
    // MARK: - Private Helper Methods
    
    private func findDaemonExecutable() throws -> String {
        // Try multiple possible locations for the daemon executable
        let possiblePaths = [
            "/usr/local/bin/anigmad",
            "/opt/homebrew/bin/anigmad",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/anigmad"
        ]
        
        // Check build directories for development
        let currentDir = FileManager.default.currentDirectoryPath
        let buildPaths = [
            "\(currentDir)/.build/release/anigmad",
            "\(currentDir)/.build/debug/anigmad",
            "\(currentDir)/anigma/.build/release/anigmad",
            "\(currentDir)/anigma/.build/debug/anigmad"
        ]
        
        for path in buildPaths + possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // If not found, return default path for installation
        return "/usr/local/bin/anigmad"
    }
    
    private func findDaemonProcess() -> pid_t? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "anigmad"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let pidString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return pid_t(Int32(pidString) ?? 0)
                }
            }
        } catch {
            // Failed to execute pgrep
        }
        
        return nil
    }
}

// MARK: - ServiceManagement Compatibility

#if !canImport(ServiceManagement)
// Fallback for systems without ServiceManagement framework
typealias SMJobRegister = @convention(c) (Int32, CFString, CFString) -> OSStatus
typealias SMJobRemove = @convention(c) (Int32, CFString) -> OSStatus
typealias SMJobSubmit = @convention(c) (Int32, CFString, CFDictionary?) -> OSStatus
typealias SMJobGetDictionary = @convention(c) (Int32, CFString) throws -> CFDictionary?

let kSMDomainUserLaunchd: Int32 = 1
let kSMJobPIDKey = "PID"
let kSMJobStartTimeKey = "StartTime"
let kSMJobMemoryUsageKey = "MemoryUsage"
#endif