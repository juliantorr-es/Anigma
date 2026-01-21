//
//  SendableViolation.swift
//  GovernedMigrationCoreTests
//
//  [Brief description of file purpose]
//

import Foundation

final class NotSendable {
    var x: Int = 0
}

actor A {
    func take(_ value: NotSendable) {}
}

func trigger() async {
    let a = A()
    let v = NotSendable()
    await a.take(v)
}
