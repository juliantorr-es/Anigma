// ⚠️ STUB_TRACK: diaplasion-module – DiaplasionModule stub (24 real files in directory but excluded from Package.swift)
// WARNING: This is a placeholder version. Real diaplasion implementations exist but are NOT included in build
// TO FIX: Update anigma/Package.swift line 887 to include real DiaplasionModule sources instead of stub-only
import Foundation
import AnigmaCore

#warning("STUB_TRACK: DiaplasionModule is running in stub-only mode; restore real sources in Package.swift when compile surface is stable.")

public enum DiaplasionModuleVersion {
    public static let major = 0
    public static let minor = 0
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)-stub"
}

public enum DiaplasionModuleResources {
    public static func urlForHappyPathSpec() throws -> URL {
        let moduleRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let bundled = moduleRoot
            .appendingPathComponent("TestFiles", isDirectory: true)
            .appendingPathComponent("diaplasion-happy", isDirectory: true)
            .appendingPathComponent("spec.json", isDirectory: false)

        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("diaplasion-happy-spec.json")
        if !FileManager.default.fileExists(atPath: fallback.path) {
            let payload = "{\"title\":\"Diaplasion Stub\",\"inputs\":[{\"path\":\"input.png\",\"label\":\"input\"}],\"metadata\":{}}"
            try payload.write(to: fallback, atomically: true, encoding: .utf8)
        }
        return fallback
    }
}

public enum DiaplasionModule: CapabilityModule {
    public static let version = DiaplasionModuleVersion.string

    public static func register(runtime: PlatformRuntime) async throws {
        _ = runtime
    }
}
