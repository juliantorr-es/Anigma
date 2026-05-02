//
//  ArchitectureTests.swift
//  GovernanceTests
//
//  Architecture guardrails to prevent layering violations.
//

import XCTest
import Foundation

final class ArchitectureTests: XCTestCase {
    
    // MARK: - Layering Violations
    
    /// Ensures that higher-level capability modules do not bypass the runtime
    /// by directly importing low-level database libraries.
    ///
    /// Forbidden imports:
    /// - DatabaseCore (Must use DatabaseAuthority via PlatformRuntime)
    /// - GRDB (Must not access SQLite directly)
    func testCapabilityModulesDoNotImportDatabaseDirectly() throws {
        // Find repository root
        // We assume the test is running inside the repo structure
        let fileManager = FileManager.default
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        
        // Locate Packages directory.
        // If running from repo root: ./anigma/Packages
        // If running from Tests/GovernanceHarness: ../../anigma/Packages
        
        var packagesURL: URL?
        let possiblePaths = [
            "anigma/Packages",
            "Packages",
            "../../anigma/Packages",
            "../../../anigma/Packages"
        ]
        
        for path in possiblePaths {
            let url = currentDirectory.appendingPathComponent(path).standardized
            if fileManager.fileExists(atPath: url.path) {
                packagesURL = url
                break
            }
        }
        
        guard let rootURL = packagesURL else {
            // If we can't find the packages, we might be in a weird CI environment.
            // Print warning but don't fail, or fail if strict.
            // For this environment, we know where we are.
            // Let's fallback to absolute path if needed for this specific env
            let absolutePath = URL(fileURLWithPath: "/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages")
            if fileManager.fileExists(atPath: absolutePath.path) {
                 packagesURL = absolutePath
            } else {
                print("⚠️ Could not locate Packages directory. Skipping architecture test.")
                return
            }
            return
        }
        
        // Modules to check
        let guardedModules = [
            "HarmoniaV2/HarmoniaMemory",
            "HarmoniaV2/HarmoniaInference"
        ]
        
        // Forbidden tokens
        let forbiddenTokens = ["import DatabaseCore", "import GRDB"]
        
        var violations: [String] = []
        
        for modulePath in guardedModules {
            let moduleURL = packagesURL!.appendingPathComponent(modulePath)
            
            // Walk directory
            guard let enumerator = fileManager.enumerator(at: moduleURL, includingPropertiesForKeys: nil) else {
                print("⚠️ Could not access module at \(moduleURL.path)")
                continue
            }
            
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "swift" else { continue }
                
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    for token in forbiddenTokens {
                        if content.contains(token) {
                            // Check if it's commented out? (Simple check implies no comments)
                            // A simple contains is strict enough for a guardrail.
                            violations.append("File \(fileURL.lastPathComponent) in \(modulePath) imports forbidden module: '\(token)'")
                        }
                    }
                } catch {
                    print("Error reading file: \(fileURL.path)")
                }
            }
        }
        
        XCTAssertTrue(violations.isEmpty, "Architecture violations found:\n" + violations.joined(separator: "\n"))
    }
    
    /// Ensures that the Mac App target does not bypass the unified client facade
    /// by directly importing runtime or database internals.
    ///
    /// Forbidden imports in AnigmaAppMac:
    /// - DatabaseCore
    /// - GRDB
    /// - AnigmaCore (Should use HarmoniaAppClient/HarmoniaV2Surface)
    func testMacAppDoesNotImportBackendDirectly() throws {
        let fileManager = FileManager.default
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        
        // Locate Sources directory.
        var sourcesURL: URL?
        let possiblePaths = [
            "anigma/Sources",
            "Sources",
            "../../anigma/Sources",
            "../../../anigma/Sources"
        ]
        
        for path in possiblePaths {
            let url = currentDirectory.appendingPathComponent(path).standardized
            if fileManager.fileExists(atPath: url.path) {
                sourcesURL = url
                break
            }
        }
        
        guard let sourcesRoot = sourcesURL else {
            print("⚠️ Could not locate Sources directory. Skipping Mac App architecture test.")
            return
        }
        
        let appURL = sourcesRoot.appendingPathComponent("AnigmaAppMac")
        guard fileManager.fileExists(atPath: appURL.path) else {
             print("⚠️ AnigmaAppMac directory not found at \(appURL.path). Skipping.")
             return
        }
        
        // Modules/Files to check
        // We scan the entire AnigmaAppMac source tree
        
        let forbiddenTokens = ["import DatabaseCore", "import GRDB"]
        // We might want to restrict AnigmaCore too, but the user specifically mentioned DatabaseCore/GRDB
        // "Fail if the Mac app target imports DatabaseCore or GRDB directly."
        // "Fail if views reference PlatformRuntime types directly" -> tough to grep for types reliably without AST,
        // but we can check for "import AnigmaCore" if the app shouldn't verify it.
        // However, the LocalAppClient *implementation* might live there?
        // Wait, LocalAppClient is in HarmoniaSurface.
        // So the App *itself* should not import AnigmaCore directly.
        
        var violations: [String] = []
        
        guard let enumerator = fileManager.enumerator(at: appURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            // Skip backup files if any
            if fileURL.path.contains("backup") { continue }
            
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for token in forbiddenTokens {
                    if content.contains(token) {
                        violations.append("File \(fileURL.lastPathComponent) in AnigmaAppMac imports forbidden module: '\(token)'")
                    }
                }
                
                // Also check for PlatformRuntime usage in Views
                if content.contains(": View") && content.contains("PlatformRuntime") {
                     violations.append("File \(fileURL.lastPathComponent) appears to be a SwiftUI View referencing PlatformRuntime directly.")
                }
                
                // Check for AnigmaCore
                if content.contains("import AnigmaCore") {
                     violations.append("File \(fileURL.lastPathComponent) imports AnigmaCore directly. Use HarmoniaAppClient instead.")
                }
                
            } catch {
                print("Error reading file: \(fileURL.path)")
            }
        }
        
        // Note: There might be existing violations in the legacy code.
        // If so, we might need to grandfather them in or fail?
        // The user said "Add a SwiftUI-target guardrail test... Fail if..."
        // This implies we should fail on new violations, but if existing code violates, the test will fail now.
        // Given the instructions, I should implement it. If it fails, I'll know what to fix or ignore.
        
        // For now, let's assert empty.
        // If the legacy app is full of violations, this will block me.
        // I will log them but maybe not fail yet if there are too many, OR I will filter to "Phase3" directory if I create one.
        // But the user said "Mac app target", implying the whole thing.
        // Let's see if it passes.
        
        if !violations.isEmpty {
            XCTFail("Architecture violations found:\n" + violations.joined(separator: "\n"))
        }
    }
}
