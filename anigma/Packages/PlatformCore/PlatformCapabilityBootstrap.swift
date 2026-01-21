//
//  PlatformCapabilityBootstrap.swift
//  PlatformCore
//
//  [Brief description of file purpose]
//

import CapabilityCore
import Foundation

/// Bootstrap for platform-specific capability providers.
public actor PlatformCapabilityBootstrap {

    /// Registers all available platform capability providers.
    /// - Parameters:
    ///   - governance: Optional governance for capability resolution.
    ///   - auditLog: Optional audit log for tracking registrations.
    public static func registerPlatformCapabilities(
        governance: CapabilityRegistry.CapabilityGovernance? = nil,
        auditLog: CapabilityRegistry.CapabilityAuditLog? = nil
    ) async {
        let registry = CapabilityRegistry.shared
        let platform = platformName()

        var registeredProviders: [String] = []

        // Register PDF providers
        #if canImport(PDFKit)
            let pdfProvider = NativePDFProvider()
            await registry.register(provider: pdfProvider)
            registeredProviders.append(pdfProvider.providerId)
        #elseif os(Linux)
            let pdfProvider = PDFiumProvider()
            await registry.register(provider: pdfProvider)
            registeredProviders.append(pdfProvider.providerId)
        #endif

        // Register compression providers
        #if canImport(Compression)
            // Register both native and enhanced compression
            let compressionProvider = NativeCompressionProvider()
            await registry.register(provider: compressionProvider)
            registeredProviders.append(compressionProvider.providerId)

            let enhancedCompressionProvider = EnhancedCompressionProvider()
            await registry.register(provider: enhancedCompressionProvider)
            registeredProviders.append(enhancedCompressionProvider.providerId)
        #endif

        // Register text shaping providers
        #if canImport(CoreText)
            let textShapingProvider = NativeTextShapingProvider()
            await registry.register(provider: textShapingProvider)
            registeredProviders.append(textShapingProvider.providerId)
        #elseif os(Linux)
            let textShapingProvider = HarfBuzzTextShapingProvider()
            await registry.register(provider: textShapingProvider)
            registeredProviders.append(textShapingProvider.providerId)
        #endif

        // Register CLI Git if available
        let gitPath = "/usr/bin/git"
        if FileManager.default.fileExists(atPath: gitPath) {
            let gitProvider = CLIGitProvider(gitPath: gitPath)
            await registry.register(provider: gitProvider)
            registeredProviders.append(gitProvider.providerId)
        }

        // Log bootstrap completion
        await auditLog?.logResolution(
            capabilityId: "bootstrap",
            principal: "system",
            success: true,
            metadata: [
                "platform": platform,
                "providers": registeredProviders.joined(separator: ", "),
                "count": "\(registeredProviders.count)"
            ]
        )
    }

    /// Returns the current platform name.
    private static func platformName() -> String {
        #if os(macOS)
            return "macOS"
        #elseif os(iOS)
            return "iOS"
        #elseif os(Linux)
            return "Linux"
        #elseif os(Windows)
            return "Windows"
        #else
            return "unknown"
        #endif
    }

    /// Returns all registered capability IDs.
    public static func registeredCapabilities() async -> [String] {
        return await CapabilityRegistry.shared.registeredCapabilityIds()
    }

    /// Returns provider count for a specific capability.
    public static func providerCount(for capabilityId: String) async -> Int {
        return await CapabilityRegistry.shared.providerCount(for: capabilityId)
    }
}
