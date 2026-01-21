# Apple Integration Deployment Guide

This guide details the steps required to deploy the "Deep Apple Integration" features (Widgets, Share Extension, File Provider) into the Anigma macOS application.

## Prerequisites

*   Xcode 15.0+
*   Apple Developer Account (for App Groups and Provisioning)
*   macOS 14.0+

## 1. App Group Configuration

All extensions communicate with the main app via a shared App Group.

1.  **Log in to Apple Developer Portal**.
2.  **Create an App Group**:
    *   Identifier: `group.com.anigma.system` (or your specific bundle prefix)
    *   Description: "Anigma Shared Data"
3.  **Enable App Group in Xcode**:
    *   Select the `AnigmaAppMac` target.
    *   Go to **Signing & Capabilities**.
    *   Click **+ Capability** and select **App Groups**.
    *   Check the `group.com.anigma.system` group.

## 2. Adding Extension Targets

You must manually add the extension targets to your Xcode project.

### A. Widget Extension
1.  **File > New > Target...**
2.  Select **macOS > Widget Extension**.
3.  Product Name: `AnigmaWidgets`.
4.  Uncheck "Include Configuration Intent" (unless you plan to add it later).
5.  **Important**: In the new target's **Build Phases > Compile Sources**, remove the default `AnigmaWidgets.swift` (or similar) file created by Xcode.
6.  Add `Sources/AnigmaExtensions/Widgets/AnigmaWidgets.swift` to the target.
7.  **Link Libraries**:
    *   Add `AnigmaSystemSpine` (and its dependencies) to **Frameworks, Libraries, and Embedded Content**.
8.  **App Group**: Enable the `group.com.anigma.system` App Group for this target.

### B. Share Extension
1.  **File > New > Target...**
2.  Select **macOS > Share Extension**.
3.  Product Name: `AnigmaShare`.
4.  **Important**: Delete the default `ShareViewController.swift` created by Xcode.
5.  Add `Sources/AnigmaExtensions/Share/ShareViewController.swift` to the target.
6.  **Info.plist**:
    *   Update `NSExtensionActivationRule` to support the types you want (PDF, Text, URL, Image).
    *   Example:
        ```xml
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>10</integer>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>10</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
        </dict>
        ```
7.  **Link Libraries**: Add `AnigmaSystemSpine`.
8.  **App Group**: Enable the App Group.

### C. File Provider Extension
1.  **File > New > Target...**
2.  Select **macOS > File Provider Extension**.
3.  Product Name: `AnigmaFiles`.
4.  **Important**: Replace the default extension logic with `Sources/AnigmaExtensions/FileProvider/FileProviderExtension.swift`.
    *   *Note*: You may need to adapt the class name or inheritance in the generated `Info.plist` to match your code.
5.  **Link Libraries**: Add `AnigmaSystemSpine`.
6.  **App Group**: Enable the App Group.

## 3. Linking AnigmaSystemSpine

Ensure that `AnigmaSystemSpine` is available to all targets. Since this is a Swift Package Manager project:

1.  In the Project Navigator, select the Project root.
2.  Select the **Anigma** project.
3.  Go to **Package Dependencies**.
4.  Ensure `Anigma` (local package) is listed if you are using a workspace, or that the targets are part of the same package.
    *   *If using an .xcodeproj generated from `swift package generate-xcodeproj`*: You will need to manually add the `AnigmaSystemSpine` product to the "Link Binary with Libraries" phase of each extension target.

## 4. Verification

1.  **Build** the main app and run it.
2.  **Verify App Group**: The app should launch without crashing on `SystemSpine.shared` initialization.
3.  **Test Extensions**:
    *   **Widget**: Open Notification Center, click "Edit Widgets", and look for Anigma.
    *   **Share**: Open Safari, share a URL, and select Anigma.
    *   **Files**: Open Finder, look for Anigma in the sidebar (may need to be enabled in System Settings > Privacy & Security > Extensions > File Provider).

## Troubleshooting

*   **"App Group Container not found"**: Ensure the App Group ID matches exactly in all targets and in the Apple Developer Portal.
*   **"Missing Library"**: Ensure `AnigmaSystemSpine` is linked to the extension targets.
*   **"Code Signing Error"**: Ensure all targets are signed with the same Team and have valid Provisioning Profiles including the App Group capability.
