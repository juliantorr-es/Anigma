//
//  CommandRenderer.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandRenderer: Sendable {
  public init() {}

  public func render(template: String, context: [String: String]) -> String {
    var result = template
    for (key, value) in context {
      result = result.replacingOccurrences(of: "$\(key)", with: value)
    }
    return result
  }
}
