//
//  SCIMProvider.swift
//  AnigmaCorporate
//
//  Implements SCIM 2.0 Provisioning logic.
//

import Foundation
import AnigmaCore

public struct SCIMUser: Codable, Sendable {
    public let id: String
    public let userName: String
    public let active: Bool
    public let emails: [SCIMEmail]

    public struct SCIMEmail: Codable, Sendable {
        public let value: String
        public let primary: Bool
    }
}

public struct SCIMGroup: Codable, Sendable {
    public let id: String
    public let displayName: String
    public let members: [SCIMMember]

    public struct SCIMMember: Codable, Sendable {
        public let value: String
        public let display: String?
    }
}

public actor SCIMProvider {
    private var users: [String: SCIMUser] = [:]
    private var groups: [String: SCIMGroup] = [:]
    private let persistenceURL: URL

    public init(persistenceURL: URL? = nil) {
        if let url = persistenceURL {
            self.persistenceURL = url
        } else {
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let appSupport = paths[0].appendingPathComponent("AnigmaCorporate")
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            self.persistenceURL = appSupport.appendingPathComponent("scim_db.json")
        }

        Task { await load() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let store = try? JSONDecoder().decode(SCIMStore.self, from: data) else { return }
        self.users = store.users
        self.groups = store.groups
    }

    private func save() {
        let store = SCIMStore(users: users, groups: groups)
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: persistenceURL)
        }
    }

    public func createUser(_ user: SCIMUser) async throws -> SCIMUser {
        users[user.id] = user
        save()
        return user
    }

    public func updateUser(_ id: String, _ user: SCIMUser) async throws -> SCIMUser {
        guard users[id] != nil else { throw CorporateError.notFound("User not found") }
        users[id] = user
        save()
        return user
    }

    public func deleteUser(_ id: String) async throws {
        users.removeValue(forKey: id)
        save()
    }

    public func getUser(_ id: String) async throws -> SCIMUser? {
        return users[id]
    }

    public func createGroup(_ group: SCIMGroup) async throws -> SCIMGroup {
        groups[group.id] = group
        save()
        return group
    }
}

private struct SCIMStore: Codable {
    let users: [String: SCIMUser]
    let groups: [String: SCIMGroup]
}
