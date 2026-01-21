//
//  AccessibilityAuthorityImpl.swift
//  AnigmaHostMac
//
//  macOS implementation of AccessibilityAuthority using ApplicationServices and CoreGraphics.
//

import Foundation
import AnigmaCore
import ApplicationServices
import CoreGraphics

/// macOS implementation of AccessibilityAuthority.
public actor AccessibilityAuthorityImpl: AccessibilityAuthority {

    public init() {}

    public func isTrusted() async -> Bool {
        let options = [kAXTrustedCheckOptionPrompt: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func requestPermissions() async -> Bool {
        let options = [kAXTrustedCheckOptionPrompt: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func getSelectedText(context: ExecutionContext) async throws -> String? {
        guard await isTrusted() else {
            throw RuntimeError.governanceViolation("Accessibility permissions not granted")
        }

        // 1. Get the system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // 2. Find the focused element
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement as? AXUIElement else {
            return nil
        }

        // 3. Try to get the selected text attribute
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)

        if textResult == .success, let text = selectedText as? String {
            return text
        }

        return nil
    }

    public func simulateTyping(_ text: String, context: ExecutionContext) async throws {
        guard await isTrusted() else {
            throw RuntimeError.governanceViolation("Accessibility permissions not granted")
        }

        let source = CGEventSource(stateID: .combinedSessionState)

        for char in text.utf16 {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
            keyUp?.post(tap: .cghidEventTap)

            // Small delay to prevent input buffer saturation
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
    }

    public func getCaretRect(context: ExecutionContext) async throws -> CGRect? {
        guard await isTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard let element = focusedElement as? AXUIElement else {
            fatalError("Failed to cast to AXUIElement")
        }

        // Cascade 1: Try AXBoundsForRange for the current selection
        if let rect = getAXBounds(for: element) { return rect }

        // Cascade 2: Try kAXFrameAttribute of the focused element (less precise)
        if let rect = getAXFrame(for: element) { return rect }

        // Cascade 3: Mouse Position Fallback
        return getMouseFallbackRect()
    }

    private func getAXBounds(for element: AXUIElement) -> CGRect? {
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)

        guard rangeResult == .success, let range = rangeValue else { return nil }

        var rectValue: AnyObject?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeAction as CFString,
            range,
            &rectValue
        )

        guard result == .success, CFGetTypeID(rectValue) == AXValueGetTypeID() else { return nil }

        guard let axValue = rectValue as? AXValue else {
            fatalError("Failed to cast to AXValue")
        }
        var rect = CGRect.zero
        if AXValueGetValue(axValue, .cgRect, &rect) {
            return rect
        }

        return nil
    }

    private func getAXFrame(for element: AXUIElement) -> CGRect? {
        var frameValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXFrameAttribute as CFString, &frameValue)

        guard result == .success, CFGetTypeID(frameValue) == AXValueGetTypeID() else { return nil }

        guard let axValue = frameValue as? AXValue else {
            fatalError("Failed to cast to AXValue")
        }
        var rect = CGRect.zero
        if AXValueGetValue(axValue, .cgRect, &rect) {
            return rect
        }

        return nil
    }

    private func getMouseFallbackRect() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        return CGRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
    }
}
