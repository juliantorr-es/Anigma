//
//  SecurityTypes.swift
//  SecurityEventsManager
//
//  Re-exports security event types from SecurityEventsContracts.
//  This file is kept for backward compatibility with existing code
//  that imports SecurityTypes from SecurityEventsManager.

import SecurityEventsContracts

// Re-export all security event types for backward compatibility
public typealias SecurityEventType = SecurityEventsContracts.SecurityEventType
public typealias SecurityEventSeverity = SecurityEventsContracts.SecurityEventSeverity
public typealias SecurityEventDetails = SecurityEventsContracts.SecurityEventDetails
public typealias SecurityEvent = SecurityEventsContracts.SecurityEvent
public typealias SecurityEventStats = SecurityEventsContracts.SecurityEventStats
