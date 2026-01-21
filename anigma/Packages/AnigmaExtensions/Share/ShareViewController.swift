//
//  ShareViewController.swift
//  AnigmaExtensions
//
//  The Share Extension entry point.
//  Uses AnigmaSystemSpine.ShareReceiver to process content.
//

import Cocoa
import Social
import AnigmaSystemSpine

class ShareViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }

    override func loadView() {
        super.loadView()

        // Insert code here to customize the view
        guard let item = self.extensionContext!.inputItems[0] as? NSExtensionItem else {
            fatalError("Failed to unwrap item")
        }
        if let attachments = item.attachments {
            NSLog("Attachments = %@", attachments as NSArray)

            Task {
                do {
                    try await ShareReceiver.shared.accept(attachments: attachments)

                    // Success
                    await MainActor.run {
                        let outputItem = NSExtensionItem()
                        // We could return modified items here if needed

                        let outputItems = [outputItem]
                        self.extensionContext!.completeRequest(returningItems: outputItems, completionHandler: nil)
                    }
                } catch {
                    // Failure
                    await MainActor.run {
                        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
                        self.extensionContext!.cancelRequest(withError: error)
                    }
                }
            }
        } else {
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

}
