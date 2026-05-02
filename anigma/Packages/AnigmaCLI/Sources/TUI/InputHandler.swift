import Foundation

/// Input handler for TUI interactions
public final class InputHandler: Sendable {
    public enum Key: Sendable {
        case char(Character)
        case up
        case down
        case left
        case right
        case home
        case end
        case delete
        case scrollUp
        case scrollDown
        case mouseDown(row: Int, col: Int)
        case mouseUp(row: Int, col: Int)
        case mouseDrag(row: Int, col: Int)
        case enter
        case backspace
        case escape
        case ctrlC
        case ctrlP
        case tab
        case space
        case unknown
    }

    private let _events: AsyncStream<Key>

    public var events: AsyncStream<Key> { _events }

    public init() {
        _events = AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                while !Task.isCancelled {
                    if let key = Self.readSync() {
                        continuation.yield(key)
                        if case .ctrlC = key {
                            continuation.finish()
                            return
                        }
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Legacy support for simple blocking read
    public func readKey() async -> Key? {
        var iterator = events.makeAsyncIterator()
        return await iterator.next()
    }

    public func readLine() async -> String? {
        var line = ""
        for await key in events {
            switch key {
            case .char(let c):
                line.append(c)
            case .backspace:
                if !line.isEmpty {
                    line.removeLast()
                }
            case .enter:
                return line
            case .ctrlC:
                return nil
            default:
                break
            }
        }
        return nil
    }

    // Blocking read logic
    private static func readSync() -> Key? {
        #if canImport(Darwin)
        var buffer = [UInt8](repeating: 0, count: 1)
        guard read(STDIN_FILENO, &buffer, 1) == 1 else { return nil }

        switch buffer[0] {
        case 9: return .tab
        case 10, 13: return .enter
        case 127: return .backspace
        case 3: return .ctrlC
        case 16: return .ctrlP
        case 27:
            // Possible escape sequence
            return readEscapeSequence()
        case 32: return .space
        case 32...126:
            let scalar = UnicodeScalar(buffer[0])
            return .char(Character(scalar))
        default:
            // Handle UTF-8 multi-byte characters roughly?
            // For now simplified single byte
            return .unknown
        }
        #else
        return nil
        #endif
    }

    private static func readEscapeSequence() -> Key {
        #if canImport(Darwin)
        var buffer = [UInt8](repeating: 0, count: 1)

        // Read '[' or 'O'
        guard read(STDIN_FILENO, &buffer, 1) == 1 else { return .escape }

        let prefix = buffer[0]

        // Read next byte
        guard read(STDIN_FILENO, &buffer, 1) == 1 else { return .escape }

        if prefix == 91 && buffer[0] == 60 { // '[' followed by '<'
            return parseSGRMouse()
        }

        if prefix == 91 { // CSI sequences: ESC [ ...
            switch buffer[0] {
            case 65: return .up    // A
            case 66: return .down  // B
            case 67: return .right // C
            case 68: return .left  // D
            case 72: return .home  // H
            case 70: return .end   // F
            case 51: // 3~ (Delete)
                var tilde = [UInt8](repeating: 0, count: 1)
                _ = read(STDIN_FILENO, &tilde, 1)
                return .delete
            default: return .unknown
            }
        } else if prefix == 79 { // SS3 sequences: ESC O ...
            switch buffer[0] {
            case 72: return .home
            case 70: return .end
            default: return .unknown
            }
        }

        return .unknown
        #else
        return .escape
        #endif
    }

    private static func parseSGRMouse() -> Key {
        #if canImport(Darwin)
        var sequence = ""
        var buffer = [UInt8](repeating: 0, count: 1)

        // Read until 'M' or 'm'
        while read(STDIN_FILENO, &buffer, 1) == 1 {
            let char = Character(UnicodeScalar(buffer[0]))
            sequence.append(char)
            if char == "M" || char == "m" { break }
        }

        // SGR format: button;x;yM (press) or button;x;ym (release)
        let isRelease = sequence.hasSuffix("m")
        let parts = sequence.dropLast().split(separator: ";")
        guard parts.count >= 3,
              let button = Int(parts[0]),
              let x = Int(parts[1]),
              let y = Int(parts[2]) else { return .unknown }

        if isRelease {
            return .mouseUp(row: y, col: x)
        }

        switch button {
        case 0: return .mouseDown(row: y, col: x)
        case 32: return .mouseDrag(row: y, col: x)
        case 64: return .scrollUp
        case 65: return .scrollDown
        default: return .unknown
        }
        #else
        return .unknown
        #endif
    }
}
