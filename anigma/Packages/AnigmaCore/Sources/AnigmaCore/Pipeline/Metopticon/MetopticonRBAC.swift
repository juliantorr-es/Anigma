//
//  MetopticonRBAC.swift
//  AnigmaCore
//
//  Role-Based Access Control for Metopticon workload visibility.
//
//  Design principles:
//  - Observability over surveillance: see infrastructure, not content
//  - Data minimization: only metadata necessary for diagnostics
//  - Purpose limitation: capacity planning, not performance evaluation
//  - Transparency: staff know what is tracked and what is not
//
//  Access model:
//  - Scope: whose workloads can be seen (self, department, institution)
//  - Granularity: how detailed (aggregated, workload-level, trace-level)
//  - Sensitivity: which fields (metrics, health, template-meta; never content)
//

import Foundation

// MARK: - Access Scope

/// Defines whose workloads a principal can observe.
public enum MetopticonAccessScope: String, Codable, Sendable {
    /// Can only see own workloads
    case selfOnly

    /// Can see workloads from direct reports or team members
    case directReports

    /// Can see all workloads in own department/org unit
    case department

    /// Can see all workloads across the institution
    case institution

    /// Can see workloads matching specific categories only
    case categoricallyScoped
}

// MARK: - Granularity Level

/// How detailed the visibility can be.
public enum MetopticonGranularity: String, Codable, Sendable, Comparable {
    /// Only aggregated statistics (counts, averages)
    case aggregatedOnly

    /// Can see individual workload status
    case workloadLevel

    /// Can see node-level traces (timing, not content)
    case traceLevel

    public static func < (lhs: MetopticonGranularity, rhs: MetopticonGranularity) -> Bool {
        let order: [MetopticonGranularity] = [.aggregatedOnly, .workloadLevel, .traceLevel]
        guard let l = order.firstIndex(of: lhs),
              let r = order.firstIndex(of: rhs) else { return false }
        return l < r
    }
}

// MARK: - Field Categories

/// Categories of fields that can be shown or hidden.
public struct MetopticonFieldCategories: OptionSet, Codable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Template/graph identifiers
    public static let templateMeta = MetopticonFieldCategories(rawValue: 1 << 0)

    /// Category labels (alt-media, grading, research)
    public static let category = MetopticonFieldCategories(rawValue: 1 << 1)

    /// Status (pending, running, failed, completed)
    public static let status = MetopticonFieldCategories(rawValue: 1 << 2)

    /// Timing metrics (duration, latency)
    public static let timing = MetopticonFieldCategories(rawValue: 1 << 3)

    /// Resource usage (CPU, GPU, memory pressure)
    public static let resources = MetopticonFieldCategories(rawValue: 1 << 4)

    /// Backend information (which inference engine)
    public static let backend = MetopticonFieldCategories(rawValue: 1 << 5)

    /// Device/node information
    public static let device = MetopticonFieldCategories(rawValue: 1 << 6)

    /// Owner identity (user, role)
    public static let ownerIdentity = MetopticonFieldCategories(rawValue: 1 << 7)

    /// Health signals (errors, retries, degradation)
    public static let health = MetopticonFieldCategories(rawValue: 1 << 8)

    /// Cache statistics (hit rate, size)
    public static let cache = MetopticonFieldCategories(rawValue: 1 << 9)

    /// All infrastructure fields (no content)
    public static let allInfrastructure: MetopticonFieldCategories = [
        .templateMeta, .category, .status, .timing,
        .resources, .backend, .device, .health, .cache
    ]

    /// Metrics-only view
    public static let metricsOnly: MetopticonFieldCategories = [
        .status, .timing, .resources, .health
    ]
}

// MARK: - Role Definitions

/// Predefined roles for Metopticon access.
public enum MetopticonRole: String, Codable, Sendable, CaseIterable {
    /// IT infrastructure administrators
    case itInfrastructure

    /// DSPS/Accessibility staff
    case dspsStaff

    /// Department chairs / program leads
    case departmentLead

    /// Faculty member
    case faculty

    /// Student (minimal or no access)
    case student

    /// System administrator (highest access)
    case systemAdmin

    /// Auditor (read-only, institution-wide)
    case auditor

    /// The default access configuration for this role
    public var defaultAccess: MetopticonAccessConfiguration {
        switch self {
        case .itInfrastructure:
            return MetopticonAccessConfiguration(
                scope: .institution,
                granularity: .traceLevel,
                allowedFields: .allInfrastructure,
                categoryFilters: nil,
                canViewOwnerIdentity: false,
                canExportData: true,
                description: "Full infrastructure visibility, no identity or content access"
            )

        case .dspsStaff:
            return MetopticonAccessConfiguration(
                scope: .categoricallyScoped,
                granularity: .workloadLevel,
                allowedFields: [.templateMeta, .category, .status, .timing, .health],
                categoryFilters: ["dsps", "alt-media", "accessibility"],
                canViewOwnerIdentity: false,
                canExportData: false,
                description: "DSPS-related pipelines only"
            )

        case .departmentLead:
            return MetopticonAccessConfiguration(
                scope: .department,
                granularity: .aggregatedOnly,
                allowedFields: [.category, .status, .timing, .health],
                categoryFilters: nil,
                canViewOwnerIdentity: false,
                canExportData: false,
                description: "Department-level aggregates only"
            )

        case .faculty:
            return MetopticonAccessConfiguration(
                scope: .selfOnly,
                granularity: .workloadLevel,
                allowedFields: [.templateMeta, .status, .timing, .health],
                categoryFilters: nil,
                canViewOwnerIdentity: true,
                canExportData: false,
                description: "Own workloads only"
            )

        case .student:
            return MetopticonAccessConfiguration(
                scope: .selfOnly,
                granularity: .aggregatedOnly,
                allowedFields: [.status],
                categoryFilters: nil,
                canViewOwnerIdentity: true,
                canExportData: false,
                description: "Minimal access - own status only"
            )

        case .systemAdmin:
            return MetopticonAccessConfiguration(
                scope: .institution,
                granularity: .traceLevel,
                allowedFields: .allInfrastructure,
                categoryFilters: nil,
                canViewOwnerIdentity: true,
                canExportData: true,
                description: "Full administrative access"
            )

        case .auditor:
            return MetopticonAccessConfiguration(
                scope: .institution,
                granularity: .workloadLevel,
                allowedFields: [.templateMeta, .category, .status, .timing, .health],
                categoryFilters: nil,
                canViewOwnerIdentity: false,
                canExportData: true,
                description: "Read-only audit access"
            )
        }
    }
}

// MARK: - Access Configuration

/// Complete access configuration for a principal.
public struct MetopticonAccessConfiguration: Codable, Sendable {
    /// Whose workloads can be observed
    public let scope: MetopticonAccessScope

    /// How detailed the visibility is
    public let granularity: MetopticonGranularity

    /// Which field categories are visible
    public let allowedFields: MetopticonFieldCategories

    /// Optional category filters (nil = all categories)
    public let categoryFilters: [String]?

    /// Whether owner identity (user ID) can be seen
    public let canViewOwnerIdentity: Bool

    /// Whether data can be exported for reports
    public let canExportData: Bool

    /// Human-readable description
    public let description: String

    public init(
        scope: MetopticonAccessScope,
        granularity: MetopticonGranularity,
        allowedFields: MetopticonFieldCategories,
        categoryFilters: [String]?,
        canViewOwnerIdentity: Bool,
        canExportData: Bool,
        description: String
    ) {
        self.scope = scope
        self.granularity = granularity
        self.allowedFields = allowedFields
        self.categoryFilters = categoryFilters
        self.canViewOwnerIdentity = canViewOwnerIdentity
        self.canExportData = canExportData
        self.description = description
    }
}

// MARK: - Principal Context

/// The authenticated principal requesting access.
public struct MetopticonPrincipal: Codable, Sendable {
    public let id: String
    public let roles: [MetopticonRole]
    public let orgUnit: String?
    public let department: String?
    public let customAccess: MetopticonAccessConfiguration?

    public init(
        id: String,
        roles: [MetopticonRole],
        orgUnit: String? = nil,
        department: String? = nil,
        customAccess: MetopticonAccessConfiguration? = nil
    ) {
        self.id = id
        self.roles = roles
        self.orgUnit = orgUnit
        self.department = department
        self.customAccess = customAccess
    }

    /// Computes effective access by merging all role defaults with custom overrides.
    public var effectiveAccess: MetopticonAccessConfiguration {
        // If custom access is defined, use it
        if let custom = customAccess {
            return custom
        }

        // Otherwise, merge role defaults (most permissive wins for scope/granularity)
        var bestScope: MetopticonAccessScope = .selfOnly
        var bestGranularity: MetopticonGranularity = .aggregatedOnly
        var combinedFields: MetopticonFieldCategories = []
        var categoryFilters: [String]?
        var canViewIdentity = false
        var canExport = false

        for role in roles {
            let access = role.defaultAccess

            // Use most permissive scope
            if scopeLevel(access.scope) > scopeLevel(bestScope) {
                bestScope = access.scope
            }

            // Use most granular level
            if access.granularity > bestGranularity {
                bestGranularity = access.granularity
            }

            // Union of fields
            combinedFields.insert(access.allowedFields)

            // If any role has no category filter, remove filter entirely
            if access.categoryFilters == nil {
                categoryFilters = nil
            } else if categoryFilters != nil, let filters = access.categoryFilters {
                categoryFilters = Array(Set((categoryFilters ?? []) + filters))
            }

            canViewIdentity = canViewIdentity || access.canViewOwnerIdentity
            canExport = canExport || access.canExportData
        }

        return MetopticonAccessConfiguration(
            scope: bestScope,
            granularity: bestGranularity,
            allowedFields: combinedFields,
            categoryFilters: categoryFilters,
            canViewOwnerIdentity: canViewIdentity,
            canExportData: canExport,
            description: "Merged from roles: \(roles.map { $0.rawValue }.joined(separator: ", "))"
        )
    }

    private func scopeLevel(_ scope: MetopticonAccessScope) -> Int {
        switch scope {
        case .selfOnly: return 0
        case .directReports: return 1
        case .department: return 2
        case .categoricallyScoped: return 2
        case .institution: return 3
        }
    }
}

// MARK: - Access Enforcement

/// Enforces RBAC rules on Metopticon data access.
public actor MetopticonAccessEnforcer {

    public init() {}

    /// Filters workload data based on principal's access configuration.
    public func filterWorkloads(
        _ workloads: [MetopticonWorkloadView],
        for principal: MetopticonPrincipal
    ) -> [MetopticonWorkloadView] {
        let access = principal.effectiveAccess

        return workloads.compactMap { workload in
            // Scope filter
            if !isInScope(workload, for: principal, access: access) {
                return nil
            }

            // Category filter
            if let categories = access.categoryFilters {
                if !categories.contains(workload.category) {
                    return nil
                }
            }

            // Field redaction
            return redactFields(workload, access: access)
        }
    }

    /// Checks if a workload is within the principal's scope.
    private func isInScope(
        _ workload: MetopticonWorkloadView,
        for principal: MetopticonPrincipal,
        access: MetopticonAccessConfiguration
    ) -> Bool {
        switch access.scope {
        case .selfOnly:
            return workload.ownerId == principal.id

        case .directReports:
            // Would check against org hierarchy
            return workload.ownerId == principal.id ||
                   workload.ownerOrgUnit == principal.orgUnit

        case .department:
            return workload.ownerDepartment == principal.department

        case .institution:
            return true

        case .categoricallyScoped:
            // Category filter handles this
            return true
        }
    }

    /// Redacts fields based on access configuration.
    private func redactFields(
        _ workload: MetopticonWorkloadView,
        access: MetopticonAccessConfiguration
    ) -> MetopticonWorkloadView {
        var result = workload

        if !access.allowedFields.contains(.ownerIdentity) && !access.canViewOwnerIdentity {
            result.ownerId = "[redacted]"
        }

        if !access.allowedFields.contains(.timing) {
            result.durationMs = nil
            result.startedAt = nil
        }

        if !access.allowedFields.contains(.resources) {
            result.resourceUsage = nil
        }

        if !access.allowedFields.contains(.backend) {
            result.backend = nil
        }

        if !access.allowedFields.contains(.device) {
            result.device = nil
        }

        if !access.allowedFields.contains(.health) {
            result.healthStatus = nil
            result.errorCount = nil
        }

        if !access.allowedFields.contains(.cache) {
            result.cacheHitRate = nil
        }

        // Granularity enforcement
        if access.granularity < .workloadLevel {
            // For aggregated-only, we shouldn't even be here with individual workloads
            // This would be handled at the query level
        }

        return result
    }

    /// Checks if principal can access trace-level data.
    public func canAccessTraces(
        for principal: MetopticonPrincipal,
        workload: MetopticonWorkloadView
    ) -> Bool {
        let access = principal.effectiveAccess
        return access.granularity >= .traceLevel &&
               isInScope(workload, for: principal, access: access)
    }
}

// MARK: - Workload View (Filtered Representation)

/// A filtered view of a workload for dashboard display.
public struct MetopticonWorkloadView: Codable, Sendable {
    public var workloadId: String
    public var templateId: String?
    public var templateName: String?
    public var category: String
    public var status: String
    public var ownerId: String
    public var ownerOrgUnit: String?
    public var ownerDepartment: String?
    public var startedAt: Date?
    public var durationMs: Int?
    public var resourceUsage: ResourceUsageView?
    public var backend: String?
    public var device: String?
    public var healthStatus: String?
    public var errorCount: Int?
    public var cacheHitRate: Double?

    public struct ResourceUsageView: Codable, Sendable {
        public var cpuPercent: Double?
        public var gpuPercent: Double?
        public var memoryMB: Int?
    }

    public init(
        workloadId: String,
        templateId: String? = nil,
        templateName: String? = nil,
        category: String,
        status: String,
        ownerId: String,
        ownerOrgUnit: String? = nil,
        ownerDepartment: String? = nil,
        startedAt: Date? = nil,
        durationMs: Int? = nil,
        resourceUsage: ResourceUsageView? = nil,
        backend: String? = nil,
        device: String? = nil,
        healthStatus: String? = nil,
        errorCount: Int? = nil,
        cacheHitRate: Double? = nil
    ) {
        self.workloadId = workloadId
        self.templateId = templateId
        self.templateName = templateName
        self.category = category
        self.status = status
        self.ownerId = ownerId
        self.ownerOrgUnit = ownerOrgUnit
        self.ownerDepartment = ownerDepartment
        self.startedAt = startedAt
        self.durationMs = durationMs
        self.resourceUsage = resourceUsage
        self.backend = backend
        self.device = device
        self.healthStatus = healthStatus
        self.errorCount = errorCount
        self.cacheHitRate = cacheHitRate
    }
}
