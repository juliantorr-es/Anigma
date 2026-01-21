//
//  CodebaseDigestor.swift
//  AnigmaCLI
//
//  Analyzes and explains the codebase during onboarding.
//

import Foundation
import AnigmaCLICore
import AnigmaCLIDatabase
import DatabaseCore
import GRDB

public actor CodebaseDigestor {
    private let database: CLIDatabaseActor
    private let workspacePath: URL

    public init(database: CLIDatabaseActor, workspacePath: URL) {
        self.database = database
        self.workspacePath = workspacePath
    }

    public struct AnalysisResult: Sendable {
        let totalFiles: Int
        let languages: [String: Int]
        let structure: ProjectStructure
        let keyModules: [ModuleInfo]
        let dependencies: [Dependency]
        let buildSystem: BuildSystemInfo
    }

    struct ProjectStructure: Sendable {
        let directories: Int
        let avgDepth: Int
        let organization: OrganizationType

        enum OrganizationType: String, Sendable {
            case monorepo = "Monorepo"
            case modular = "Modular"
            case flatStructure = "Flat"
            case layered = "Layered"
        }
    }

    struct ModuleInfo: Sendable {
        let name: String
        let path: String
        let fileCount: Int
        let language: String
        let purpose: String
    }

    struct Dependency: Sendable {
        let name: String
        let version: String?
        let source: DependencySource

        enum DependencySource: String, Sendable {
            case swiftpm = "Swift Package Manager"
            case cocoapods = "CocoaPods"
            case npm = "npm"
            case pip = "pip"
            case cargo = "Cargo"
            case maven = "Maven"
            case gradle = "Gradle"
        }
    }

    struct BuildSystemInfo: Sendable {
        let type: BuildSystem
        let configured: Bool
        let targets: [String]

        enum BuildSystem: String, Sendable {
            case swiftpm = "Swift Package Manager"
            case xcode = "Xcode"
            case cmake = "CMake"
            case make = "Make"
            case gradle = "Gradle"
            case maven = "Maven"
            case cargo = "Cargo"
            case npm = "npm"
            case unknown = "Unknown"
        }
    }

    public func analyze() async throws -> AnalysisResult {
        print("📊 Analyzing codebase structure...")

        let files = try scanFiles()
        let languages = analyzeLanguages(files)
        let structure = try analyzeStructure()
        let buildSystem = try detectBuildSystem()
        let dependencies = try extractDependencies(buildSystem: buildSystem)
        let modules = try identifyModules(files: files, structure: structure)

        return AnalysisResult(
            totalFiles: files.count,
            languages: languages,
            structure: structure,
            keyModules: modules,
            dependencies: dependencies,
            buildSystem: buildSystem
        )
    }

    public func generateExplanation(result: AnalysisResult) async -> String {
        var explanation = """

        📦 **Codebase Overview**

        This project contains \(result.totalFiles) files across \(result.languages.count) programming languages.

        **Languages:**
        """

        for (lang, count) in result.languages.sorted(by: { $0.value > $1.value }) {
            let percentage = (Double(count) / Double(result.totalFiles)) * 100
            explanation += "\n  • \(lang): \(count) files (\(String(format: "%.1f", percentage))%)"
        }

        explanation += """


        **Structure:** \(result.structure.organization.rawValue)
          - \(result.structure.directories) directories
          - Average nesting depth: \(result.structure.avgDepth)

        **Build System:** \(result.buildSystem.type.rawValue)
        """

        if !result.buildSystem.targets.isEmpty {
            explanation += "\n  Targets: \(result.buildSystem.targets.joined(separator: ", "))"
        }

        if !result.dependencies.isEmpty {
            explanation += "\n\n**Dependencies:** \(result.dependencies.count) external packages"
            for dep in result.dependencies.prefix(5) {
                explanation += "\n  • \(dep.name)" + (dep.version.map { " (\($0))" } ?? "")
            }
            if result.dependencies.count > 5 {
                explanation += "\n  • ... and \(result.dependencies.count - 5) more"
            }
        }

        if !result.keyModules.isEmpty {
            explanation += "\n\n**Key Modules:**"
            for module in result.keyModules.prefix(5) {
                explanation += "\n  • \(module.name): \(module.purpose) (\(module.fileCount) files)"
            }
        }

        explanation += """


        **How to Use Anigma CLI:**

        1. **Chat Mode**: Ask questions about your codebase
           ```
           anigma-cli chat
           ```

        2. **Code Intelligence**: Search with semantic understanding
           ```
           /search "authentication flow"
           /explain User.swift
           ```

        3. **Refactoring**: Get guided refactoring suggestions
           ```
           /refactor --target Authentication
           /improve --scope security
           ```

        4. **Documentation**: Generate explanations and docs
           ```
           /document --module Core
           /explain --concept "dependency injection"
           ```

        The CLI has indexed your codebase and is ready to assist!
        """

        return explanation
    }

    public func startBackgroundIndexing() {
        Task.detached(priority: .background) { [digestor = self] in
            print("\n🔁 Background indexing started...")
            do {
                let result = try await digestor.analyze()
                print("✅ Background indexing complete: \(result.totalFiles) files analyzed.")
            } catch {
                print("⚠️ Background indexing failed: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    private func scanFiles() throws -> [URL] {
        let fileManager = FileManager.default
        var files: [URL] = []

        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        let enumerator = fileManager.enumerator(
            at: workspacePath,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            files.append(fileURL)
        }

        return files
    }

    private func analyzeLanguages(_ files: [URL]) -> [String: Int] {
        var languages: [String: Int] = [:]

        for file in files {
            let ext = file.pathExtension.lowercased()
            let language = languageForExtension(ext)
            languages[language, default: 0] += 1
        }

        return languages
    }

    private func languageForExtension(_ ext: String) -> String {
        switch ext {
        case "swift": return "Swift"
        case "m", "mm": return "Objective-C"
        case "c": return "C"
        case "cpp", "cc", "cxx": return "C++"
        case "h", "hpp": return "Headers"
        case "js", "jsx": return "JavaScript"
        case "ts", "tsx": return "TypeScript"
        case "py": return "Python"
        case "rs": return "Rust"
        case "go": return "Go"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "rb": return "Ruby"
        case "php": return "PHP"
        case "md": return "Markdown"
        case "json": return "JSON"
        case "yaml", "yml": return "YAML"
        case "toml": return "TOML"
        default: return "Other"
        }
    }

    private func analyzeStructure() throws -> ProjectStructure {
        let fileManager = FileManager.default
        var dirCount = 0
        var maxDepth = 0

        let enumerator = fileManager.enumerator(
            at: workspacePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            if let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                dirCount += 1
                let depth = url.pathComponents.count - workspacePath.pathComponents.count
                maxDepth = max(maxDepth, depth)
            }
        }

        let avgDepth = min(maxDepth, 10)
        let organization = determineOrganization(dirCount: dirCount, depth: avgDepth)

        return ProjectStructure(
            directories: dirCount,
            avgDepth: avgDepth,
            organization: organization
        )
    }

    private func determineOrganization(dirCount: Int, depth: Int) -> ProjectStructure.OrganizationType {
        if dirCount > 100 && depth > 5 {
            return .monorepo
        } else if dirCount > 30 && depth > 3 {
            return .modular
        } else if depth > 4 {
            return .layered
        } else {
            return .flatStructure
        }
    }

    private func detectBuildSystem() throws -> BuildSystemInfo {
        let fileManager = FileManager.default
        let buildFiles = [
            ("Package.swift", BuildSystemInfo.BuildSystem.swiftpm),
            ("CMakeLists.txt", .cmake),
            ("Makefile", .make),
            ("build.gradle", .gradle),
            ("pom.xml", .maven),
            ("Cargo.toml", .cargo),
            ("package.json", .npm)
        ]

        for (file, system) in buildFiles {
            let path = workspacePath.appendingPathComponent(file)
            if fileManager.fileExists(atPath: path.path) {
                let targets = try extractTargets(buildFile: path, system: system)
                return BuildSystemInfo(type: system, configured: true, targets: targets)
            }
        }

        return BuildSystemInfo(type: .unknown, configured: false, targets: [])
    }

    private func extractTargets(buildFile: URL, system: BuildSystemInfo.BuildSystem) throws -> [String] {
        let content = try String(contentsOf: buildFile)
        var targets: [String] = []

        switch system {
        case .swiftpm:
            let execPattern = #"\.executable\(name: "([^"]+)"#
            let libPattern = #"\.library\(name: "([^"]+)"#

            if let execRegex = try? NSRegularExpression(pattern: execPattern),
               let libRegex = try? NSRegularExpression(pattern: libPattern) {
                let nsContent = content as NSString
                let execMatches = execRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
                let libMatches = libRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

                for match in execMatches + libMatches {
                    if match.numberOfRanges > 1 {
                        let name = nsContent.substring(with: match.range(at: 1))
                        targets.append(name)
                    }
                }
            }
        default:
            break
        }

        return targets
    }

    private func extractDependencies(buildSystem: BuildSystemInfo) throws -> [Dependency] {
        var deps: [Dependency] = []

        switch buildSystem.type {
        case .swiftpm:
            let packagePath = workspacePath.appendingPathComponent("Package.swift")
            if let content = try? String(contentsOf: packagePath) {
                let pattern = #"\.package\(url: "([^"]+)", from: "([^"]+)"\)"#
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let nsContent = content as NSString
                    let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

                    for match in matches {
                        if match.numberOfRanges > 2 {
                            let url = nsContent.substring(with: match.range(at: 1))
                            let version = nsContent.substring(with: match.range(at: 2))
                            let name = URL(string: url)?.lastPathComponent.replacingOccurrences(of: ".git", with: "") ?? "unknown"
                            deps.append(Dependency(name: name, version: version, source: .swiftpm))
                        }
                    }
                }
            }
        default:
            break
        }

        return deps
    }

    private func identifyModules(files: [URL], structure: ProjectStructure) throws -> [ModuleInfo] {
        var modules: [ModuleInfo] = []
        let fileManager = FileManager.default

        let moduleDirs = ["Sources", "Packages", "Modules", "src", "lib"]

        for dir in moduleDirs {
            let modulePath = workspacePath.appendingPathComponent(dir)
            guard fileManager.fileExists(atPath: modulePath.path) else { continue }

            if let contents = try? fileManager.contentsOfDirectory(at: modulePath, includingPropertiesForKeys: [.isDirectoryKey]) {
                for item in contents {
                    if let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                        let moduleFiles = files.filter { $0.path.hasPrefix(item.path) }
                        if !moduleFiles.isEmpty {
                            let purpose = inferModulePurpose(name: item.lastPathComponent)
                            modules.append(ModuleInfo(
                                name: item.lastPathComponent,
                                path: item.path,
                                fileCount: moduleFiles.count,
                                language: "Swift",
                                purpose: purpose
                            ))
                        }
                    }
                }
            }
        }

        return modules.sorted { $0.fileCount > $1.fileCount }
    }

    private func inferModulePurpose(name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("test") { return "Testing" }
        if lowercased.contains("core") { return "Core functionality" }
        if lowercased.contains("ui") || lowercased.contains("view") { return "User interface" }
        if lowercased.contains("network") || lowercased.contains("api") { return "Networking" }
        if lowercased.contains("data") || lowercased.contains("db") { return "Data layer" }
        if lowercased.contains("util") || lowercased.contains("helper") { return "Utilities" }
        if lowercased.contains("model") { return "Data models" }
        if lowercased.contains("service") { return "Business logic" }

        return "Module"
    }
}
