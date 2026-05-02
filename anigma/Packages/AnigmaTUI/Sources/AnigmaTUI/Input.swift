import Foundation

public enum Key: Sendable {
    case char(Character)
    case enter
    case backspace
    case escape
    case up
    case down
    case left
    case right
    case tab
    case unknown([UInt8])
}

public actor TerminalInput {
    private var isRawMode = false
    private let stdin = FileHandle.standardInput

    public init() {}

    public func enableRawMode() {
        guard !isRawMode else { return }
        // Use stty to set raw mode
        let task = Process()
        task.launchPath = "/bin/stty"
        task.arguments = ["-f", "/dev/stdin", "raw", "-echo"]
        task.launch()
        task.waitUntilExit()
        isRawMode = true
    }

    public func disableRawMode() {
        guard isRawMode else { return }
        let task = Process()
        task.launchPath = "/bin/stty"
        task.arguments = ["-f", "/dev/stdin", "-raw", "echo"]
        task.launch()
        task.waitUntilExit()
        isRawMode = false
    }

    public func nextKey() async throws -> Key {
        // Read from stdin
        // This is a simplified async read
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let data = self.stdin.availableData
                if data.isEmpty {
                    // This might block if not careful, in a real impl we'd use a better way
                }
                let bytes = [UInt8](data)
                continuation.resume(returning: self.decode(bytes))
            }
        }
    }

    nonisolated private func decode(_ bytes: [UInt8]) -> Key {
        if bytes.isEmpty { return .unknown([]) }

        if bytes.count == 1 {
            switch bytes[0] {
            case 13: return .enter
            case 127: return .backspace
            case 27: return .escape
            case 9: return .tab
            default: return .char(Character(UnicodeScalar(bytes[0])))
            }
        }

        if bytes.count >= 3 && bytes[0] == 27 && bytes[1] == 91 {
            switch bytes[2] {
            case 65: return .up
            case 66: return .down
            case 67: return .right
            case 68: return .left
            default: break
            }
        }

        return .unknown(bytes)
    }
}
