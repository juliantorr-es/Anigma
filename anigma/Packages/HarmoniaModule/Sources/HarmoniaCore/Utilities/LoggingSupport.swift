//
//  LoggingSupport.swift
//  HarmoniaModule
//
//  Logging utility functions for HarmoniaModule.
//

import Foundation
import os.log

private let log = Logger(subsystem: "com.anigma.harmonia", category: "logging")

/// Log a debug message.
func logDebug(_ message: String, category: String = "Debug") {
    log.info("[\(category)] 🔍 \(message)")
}

/// Log an info message.
func logInfo(_ message: String, category: String = "Info") {
    log.info("[\(category)] ℹ️ \(message)")
}

/// Log a warning message.
func logWarning(_ message: String, category: String = "Warning") {
    log.info("[\(category)] ⚠️ \(message)")
}

/// Log an error message.
func logError(_ message: String, category: String = "Error") {
    log.info("[\(category)] ❌ \(message)")
}
