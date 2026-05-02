//
//  SendableHelpers.swift
//  SaturationInferenceCore
//
//  Thread-safe helpers for Sendable conformance in Swift 6
//
//  Provides utilities for wrapping mutable state in Sendable classes
//  while maintaining thread-safety.
//

import Foundation

// MARK: - Thread-Safe Mutable Box for Sendable Conformance

/// A thread-safe mutable box that conforms to Sendable
/// 
/// Used to wrap mutable state in Sendable classes where the state
/// is protected by locks or other synchronization mechanisms.
/// 
/// In Swift 6, mutable stored properties in Sendable classes are errors.
/// This box provides a way to have mutable state while conforming to Sendable.
/// 
/// - Note: The `@unchecked Sendable` annotation tells the compiler that
///   we guarantee thread-safety through our internal synchronization (NSLock).
/// 
/// - Warning: All access to the wrapped value must go through the
///   `value` property or `mutate` function to ensure proper synchronization.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
internal final class MutableBox<T>: @unchecked Sendable {
  private var _value: T
  private let lock = NSLock()

  /// Create a mutable box with an initial value
  /// - Parameter value: Initial value
  internal init(_ value: T) {
    self._value = value
  }

  /// The wrapped value
  /// 
  /// All accesses are protected by the internal lock.
  internal var value: T {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }

  /// Mutate the wrapped value atomically
  /// - Parameter body: Closure that mutates the value
  internal func mutate(_ body: (inout T) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    body(&_value)
  }
}
