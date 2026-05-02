import Foundation

#if os(macOS)
import AppKit
#endif

public struct NotificationManager {
    public static func send(title: String, message: String) {
        #if os(macOS)
        let script = """
        display notification "\(message)" with title "\(title)" sound name "Glass"
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        try? process.run()
        #else
        // Fallback for Linux or other platforms (e.g. print bell)
        print("\u{0007}") // Bell
        #endif
    }
}
