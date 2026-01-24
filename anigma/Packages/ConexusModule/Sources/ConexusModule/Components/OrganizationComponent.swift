//
//  OrganizationComponent.swift
//  ConexusModule
//
//  Component representing an organization in the CRM.
//

import Foundation
import AnigmaCore

/// Component representing an organization (company, institution, etc.) in the CRM.
public struct OrganizationComponent: Component, Sendable, Codable {
    public let organizationId: OrganizationId
    public var organizationType: OrganizationType

    // Basic information
    public var name: String
    public var legalName: String?
    public var description: String?
    public var website: URL?
    public var industry: String?

    // Contact details
    public var emails: [EmailAddress]
    public var phones: [PhoneNumber]
    public var addresses: [MailingAddress]

    // Hierarchy
    public var parentOrganizationId: OrganizationId?
    public var childOrganizationIds: [OrganizationId]

    // Size and financials
    public var employeeCount: Int?
    public var annualRevenue: Decimal?
    public var fiscalYearEnd: Int?      // Month (1-12)

    // Classification
    public var tags: Set<String>
    public var customFields: [String: String]

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var lastContactedAt: Date?
    public var ownerId: String?

    public init(
        organizationId: OrganizationId = OrganizationId(),
        organizationType: OrganizationType = .company,
        name: String,
        legalName: String? = nil,
        description: String? = nil,
        website: URL? = nil,
        industry: String? = nil,
        emails: [EmailAddress] = [],
        phones: [PhoneNumber] = [],
        addresses: [MailingAddress] = [],
        parentOrganizationId: OrganizationId? = nil,
        childOrganizationIds: [OrganizationId] = [],
        employeeCount: Int? = nil,
        annualRevenue: Decimal? = nil,
        fiscalYearEnd: Int? = nil,
        tags: Set<String> = [],
        customFields: [String: String] = [:],
        ownerId: String? = nil
    ) {
        self.organizationId = organizationId
        self.organizationType = organizationType
        self.name = name
        self.legalName = legalName
        self.description = description
        self.website = website
        self.industry = industry
        self.emails = emails
        self.phones = phones
        self.addresses = addresses
        self.parentOrganizationId = parentOrganizationId
        self.childOrganizationIds = childOrganizationIds
        self.employeeCount = employeeCount
        self.annualRevenue = annualRevenue
        self.fiscalYearEnd = fiscalYearEnd
        self.tags = tags
        self.customFields = customFields
        self.createdAt = Date()
        self.updatedAt = Date()
        self.ownerId = ownerId
    }

    /// Primary email address.
    public var primaryEmail: String? {
        emails.first { $0.isPrimary }?.address ?? emails.first?.address
    }

    /// Primary phone number.
    public var primaryPhone: String? {
        phones.first { $0.isPrimary }?.number ?? phones.first?.number
    }

    /// Primary address.
    public var primaryAddress: MailingAddress? {
        addresses.first { $0.isPrimary } ?? addresses.first
    }
}
