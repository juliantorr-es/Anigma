//
//  SafariWebExtensionHandler.swift
//  AnigmaAppMac
//
//  Handles native messaging from the Safari Extension.
//

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems[0] as? NSExtensionItem else {
            fatalError("Failed to cast to NSExtensionItem")
        }
        let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any]

        os_log(.default, "Received message from browser: %@", String(describing: message))

        var responseData: [String: Any] = ["status": "received"]

        if let message = message, let type = message["type"] as? String {
            if type == "capture" {
                handleCapture(message)
                responseData["status"] = "captured"
            }
        }

        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: responseData ]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func handleCapture(_ message: [String: Any]) {
        guard let title = message["title"] as? String,
              let url = message["url"] as? String,
              let html = message["html"] as? String else { return }

        // Save to App Group Defaults for the main app to pick up
        // Note: Requires App Group entitlement "group.com.anigma.app"
        let suiteName = "group.com.anigma.app"
        if let userDefaults = UserDefaults(suiteName: suiteName) {
            var captures = userDefaults.array(forKey: "pendingCaptures") as? [[String: String]] ?? []
            captures.append([
                "id": UUID().uuidString,
                "title": title,
                "url": url,
                "html": html,
                "timestamp": String(Date().timeIntervalSince1970)
            ])
            userDefaults.set(captures, forKey: "pendingCaptures")
        }
    }
}
