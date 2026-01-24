//
//  ContactComponent.swift
//  ConexusModule
//
//  Component representing a contact (person) in the CRM.
//

import Foundation
import AnigmaCore

/// Component representing a contact (person) in the CRM.
public struct ContactComponent: Component, Sendable {
    public let contactId: ContactId
    public var contactType: ContactType

    // Basic information
    public var prefix: String?          // Mr., Ms., Dr., etc.
    public var firstName: String
    public var middleName: String?
    public var lastName: String
    public var suffix: String?          // Jr., III, PhD, etc.
    public var nickname: String?

    // Contact details
    public var emails: [EmailAddress]
    public var phones: [PhoneNumber]
    public var addresses: [MailingAddress]

    // Professional info
    public var title: String?
    public var department: String?
    public var organizationId: OrganizationId?

    // Preferences
    public var preferredContactMethod: ContactMethod
    public var preferredLanguage: String
    public var timezone: String?

    // Accessibility
    public var accommodationNeeds: [String]
    public var preferredFormats: [AccessibleFormat]

    // Classification
    public var tags: Set<String>
    public var customFields: [String: String]

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var lastContactedAt: Date?
    public var ownerId: String?         // Assigned user/agent

    public init(
        contactId: ContactId = ContactId(),
        contactType: ContactType = .individual,
        firstName: String,
        lastName: String,
        prefix: String? = nil,
        middleName: String? = nil,
        suffix: String? = nil,
        nickname: String? = nil,
        emails: [EmailAddress] = [],
        phones: [PhoneNumber] = [],
        addresses: [MailingAddress] = [],
        title: String? = nil,
        department: String? = nil,
        organizationId: OrganizationId? = nil,
        preferredContactMethod: ContactMethod = .email,
        preferredLanguage: String = "en",
        timezone: String? = nil,
        accommodationNeeds: [String] = [],
        preferredFormats: [AccessibleFormat] = [],
        tags: Set<String> = [],
        customFields: [String: String] = [:],
        ownerId: String? = nil
    ) {
        self.contactId = contactId
        self.contactType = contactType
        self.firstName = firstName
        self.lastName = lastName
        self.prefix = prefix
        self.middleName = middleName
        self.suffix = suffix
        self.nickname = nickname
        self.emails = emails
        self.phones = phones
        self.addresses = addresses
        self.title = title
        self.department = department
        self.organizationId = organizationId
        self.preferredContactMethod = preferredContactMethod
        self.preferredLanguage = preferredLanguage
        self.timezone = timezone
        self.accommodationNeeds = accommodationNeeds
        self.preferredFormats = preferredFormats
        self.tags = tags
        self.customFields = customFields
        self.createdAt = Date()
        self.updatedAt = Date()
        self.ownerId = ownerId
    }

    /// Full name combining all name parts.
    public var fullName: String {
        var parts: [String] = []
        if let prefix = prefix { parts.append(prefix) }
        parts.append(firstName)
        if let middle = middleName { parts.append(middle) }
        parts.append(lastName)
        if let suffix = suffix { parts.append(suffix) }
        return parts.joined(separator: " ")
    }

    /// Display name (nickname or first name).
    public var displayName: String {
        nickname ?? firstName
    }

    /// Primary email address.
    public var primaryEmail: String? {
        emails.first { $0.isPrimary }?.address ?? emails.first?.address
    }

    /// Primary phone number.
    public var primaryPhone: String? {
        phones.first { $0.isPrimary }?.number ?? phones.first?.number
    }
}

// MARK: - Contact Sub-types

/// Email address with type and flags.
public struct EmailAddress: Codable, Sendable, Equatable {
    public let address: String
    public var type: EmailType
    public var isPrimary: Bool
    public var isVerified: Bool

    public init(address: String, type: EmailType = .work, isPrimary: Bool = false, isVerified: Bool = false) {
        self.address = address
        self.type = type
        self.isPrimary = isPrimary
        self.isVerified = isVerified
    }

    public enum EmailType: String, Codable, Sendable, CaseIterable {
        case work
        case personal
        case school
        case other
    }
}

/// Phone number with type and flags.
public struct PhoneNumber: Codable, Sendable, Equatable {
    public let number: String
    public var type: PhoneType
    public var isPrimary: Bool
    public var canSMS: Bool

    public init(number: String, type: PhoneType = .mobile, isPrimary: Bool = false, canSMS: Bool = true) {
        self.number = number
        self.type = type
        self.isPrimary = isPrimary
        self.canSMS = canSMS
    }

    public enum PhoneType: String, Codable, Sendable, CaseIterable {
        case mobile
        case work
        case home
        case fax
        case other
    }
}

/// Mailing address.
public struct MailingAddress: Codable, Sendable, Equatable {
    public var street1: String
    public var street2: String?
    public var city: String
    public var state: String
    public var postalCode: String
    public var country: String
    public var type: AddressType
    public var isPrimary: Bool

    public init(
        street1: String,
        street2: String? = nil,
        city: String,
        state: String,
        postalCode: String,
        country: String = "US",
        type: AddressType = .work,
        isPrimary: Bool = false
    ) {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.type = type
        self.isPrimary = isPrimary
    }

    public enum AddressType: String, Codable, Sendable, CaseIterable {
        case work
        case home
        case mailing
        case billing
        case shipping
        case other
    }

    public var formatted: String {
        var lines = [street1]
        if let street2 = street2, !street2.isEmpty { lines.append(street2) }
        lines.append("\(city), \(state) \(postalCode)")
        if country != "US" { lines.append(country) }
        return lines.joined(separator: "\n")
    }
}

/// Preferred contact method.
public enum ContactMethod: String, Codable, Sendable, CaseIterable {
    case email
    case phone
    case sms
    case mail
    case inPerson
    case noContact
}

/// Accessible format preferences.
public enum AccessibleFormat: String, Codable, Sendable, CaseIterable {
    case standardPrint
    case largePrint
    case braille
    case audio
    case electronic
    case signLanguage
    case easyRead
    case plainLanguage
}
