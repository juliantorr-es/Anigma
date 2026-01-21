import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Performs system capability assessment for model recommendations
struct SystemBenchmark {
    func run() async throws -> BenchmarkResults {
        async let cpu = benchmarkCPU()
        async let memory = benchmarkMemory()
        async let gpu = benchmarkGPU()
        async let disk = benchmarkDisk()

        return try await BenchmarkResults(
            cpu: cpu,
            memory: memory,
            gpu: gpu,
            disk: disk
        )
    }

    private func benchmarkCPU() async throws -> CPUBenchmark {
        let cores = ProcessInfo.processInfo.processorCount
        let model = getCPUModel()

        // Run simple arithmetic benchmark
        let start = Date()
        var sum: Double = 0
        for i in 0..<10_000_000 {
            sum += Double(i) * 1.5
        }
        let duration = Date().timeIntervalSince(start)
        let score = 10_000_000 / duration

        return CPUBenchmark(
            model: model,
            cores: cores,
            performanceScore: Int(score),
            architecture: getArchitecture()
        )
    }

    private func benchmarkMemory() async throws -> MemoryBenchmark {
        #if canImport(Darwin)
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        let totalGB = Double(size) / 1_073_741_824 // Convert to GB
        #else
        let totalGB = 16.0 // Default fallback
        #endif

        // Measure memory bandwidth
        let arraySize = 10_000_000
        var data = [Double](repeating: 0, count: arraySize)

        let start = Date()
        for i in 0..<arraySize {
            data[i] = Double(i)
        }
        let duration = Date().timeIntervalSince(start)
        let bandwidthGBps = (Double(arraySize) * 8) / (duration * 1_000_000_000)

        return MemoryBenchmark(
            totalGB: totalGB,
            bandwidthGBps: bandwidthGBps
        )
    }

    private func benchmarkGPU() async throws -> GPUBenchmark? {
        #if canImport(Metal)
        import Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        return GPUBenchmark(
            model: device.name,
            memoryGB: Double(device.recommendedMaxWorkingSetSize) / 1_073_741_824,
            isAppleSilicon: device.supportsFamily(.apple7) || device.supportsFamily(.apple8),
            computeUnits: 0 // Metal doesn't expose this directly
        )
        #else
        return nil
        #endif
    }

    private func benchmarkDisk() async throws -> DiskBenchmark {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("benchmark_\(UUID().uuidString)")

        // Write test
        let testData = Data(repeating: 0, count: 100_000_000) // 100MB
        let writeStart = Date()
        try testData.write(to: testFile)
        let writeSpeed = 100.0 / Date().timeIntervalSince(writeStart) // MB/s

        // Read test
        let readStart = Date()
        _ = try Data(contentsOf: testFile)
        let readSpeed = 100.0 / Date().timeIntervalSince(readStart) // MB/s

        try? FileManager.default.removeItem(at: testFile)

        // Get available space
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: tempDir.path)
        let freeSpace = (attributes[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
        let availableGB = freeSpace / 1_073_741_824

        return DiskBenchmark(
            availableGB: availableGB,
            readSpeedMBps: readSpeed,
            writeSpeedMBps: writeSpeed
        )
    }

    private func getCPUModel() -> String {
        #if canImport(Darwin)
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        return String(cString: machine)
        #else
        return "Unknown CPU"
        #endif
    }

    private func getArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

struct BenchmarkResults: Codable {
    let cpu: CPUBenchmark
    let memory: MemoryBenchmark
    let gpu: GPUBenchmark?
    let disk: DiskBenchmark

    var isHighEnd: Bool {
        cpu.cores >= 8 && memory.totalGB >= 32
    }

    var isMidRange: Bool {
        cpu.cores >= 4 && memory.totalGB >= 16
    }

    var hasAppleSilicon: Bool {
        gpu?.isAppleSilicon ?? false
    }
}

struct CPUBenchmark: Codable {
    let model: String
    let cores: Int
    let performanceScore: Int
    let architecture: String
}

struct MemoryBenchmark: Codable {
    let totalGB: Double
    let bandwidthGBps: Double
}

struct GPUBenchmark: Codable {
    let model: String
    let memoryGB: Double
    let isAppleSilicon: Bool
    let computeUnits: Int
}

struct DiskBenchmark: Codable {
    let availableGB: Double
    let readSpeedMBps: Double
    let writeSpeedMBps: Double
}
