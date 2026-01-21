//
//  UpdateCompat.swift
//  AnigmaTestSupport
//
//  [Brief description of file purpose]
//

import AnigmaCore

public enum UpdateCompat {
  public static func addComponentMigration(
    id: String,
    version: GraphSemanticVersion,
    component: String
  ) -> AddComponentMigrationBridge {
    AddComponentMigrationBridge(id: id, version: version, component: component)
  }
}

public struct AddComponentMigrationBridge: Sendable {
  let id: String
  let version: GraphSemanticVersion
  let component: String
}
