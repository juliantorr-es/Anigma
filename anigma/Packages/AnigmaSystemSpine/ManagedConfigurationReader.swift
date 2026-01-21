//
//  ManagedConfigurationReader.swift
//  AnigmaSystemSpine
//
//  Reads Managed App Configuration pushed by MDM.
//

import Foundation

public actor ManagedConfigurationReader {
    public static let shared = ManagedConfigurationReader()

    private var _configuration: [String: Any] = [:]

    public var configuration: [String: Any] {
        return _configuration
    }

    private init() {
        if let managedConf = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") {
            self._configuration = managedConf
        } else {
            self._configuration = [:]
        }

        Task { @MainActor in
            _ = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { await self?.refresh() }
            }
        }
    }

    public func refresh() {
        if let managedConf = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") {
            self._configuration = managedConf
        } else {
            self._configuration = [:]
        }
    }

    public func getValue<T>(forKey key: String) -> T? {
        return _configuration[key] as? T
    }
}
