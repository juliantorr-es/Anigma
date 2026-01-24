//
//  SystemBenchmark.swift
//  AnigmaCore
//
//  System performance benchmarking for model recommendations.
//
//

import Foundation

public enum SystemMLBackend: String, Codable, Sendable, CaseIterable {
    case mlx
    case coreml
    case gguf
    case safetensors

    public var displayName: String {
        switch self {
        case .mlx: return "MLX"
        case .coreml: return "CoreML"
        case .gguf: return "GGUF"
        case .safetensors: return "Safetensors"
        }
    }
}

public actor SystemBenchmark {
    public struct Result: Codable, Sendable {
        public let cpuScore: Double
        public let gpuScore: Double?
        public let memoryGB: Int
        public let storageScore: Double
        public let overallScore: Double
        public let tier: Tier
        public let recommendedMemoryGB: Int
        public let recommendedBackends: [SystemMLBackend]
        public let recommendedModelSize: String
        public let benchmarkDate: Date

        public var formattedScore: String {
            String(format: "%.0f", overallScore)
        }

        public var tierDescription: String {
            switch tier {
            case .minimum:
                return "Basic - Suitable for small models (3-7B parameters)"
            case .standard:
                return "Standard - Suitable for medium models (7-14B parameters)"
            case .powerful:
                return "Powerful - Suitable for large models (14-34B parameters)"
            case .extreme:
                return "Extreme - Suitable for very large models (34B+ parameters)"
            }
        }
    }

    public enum Tier: String, Codable, Sendable, CaseIterable {
        case minimum
        case standard
        case powerful
        case extreme

        public var displayName: String {
            switch self {
            case .minimum: return "Minimum"
            case .standard: return "Standard"
            case .powerful: return "Powerful"
            case .extreme: return "Extreme"
            }
        }

        public var recommendedModelSize: String {
            switch self {
            case .minimum: return "3B - 7B"
            case .standard: return "7B - 14B"
            case .powerful: return "14B - 34B"
            case .extreme: return "34B+"
            }
        }

        public var maxModelSizeGB: Int {
            switch self {
            case .minimum: return 8
            case .standard: return 16
            case .powerful: return 48
            case .extreme: return 128
            }
        }
    }

    private let fileManager = FileManager.default

    public init() {}

    public func runBenchmark() async -> Result {
        async let cpuTask = benchmarkCPU()
        async let gpuTask = benchmarkGPU()
        async let memoryTask = benchmarkMemory()
        async let storageTask = benchmarkStorage()

        let cpuScore = await cpuTask
        let gpuScore = await gpuTask
        let memoryScore = await memoryTask
        let storageScore = await storageTask

        let memoryGB = await getMemoryGB()

        let overallScore = calculateOverallScore(
            cpu: cpuScore,
            gpu: gpuScore,
            memory: memoryScore,
            storage: storageScore
        )

        let tier = determineTier(from: overallScore, gpuScore: gpuScore, memoryGB: memoryGB)
        let recommendedMemoryGB = tier.maxModelSizeGB / 2
        let recommendedBackends = determineBackends(gpuScore: gpuScore, tier: tier)

        return Result(
            cpuScore: cpuScore,
            gpuScore: gpuScore,
            memoryGB: memoryGB,
            storageScore: storageScore,
            overallScore: overallScore,
            tier: tier,
            recommendedMemoryGB: recommendedMemoryGB,
            recommendedBackends: recommendedBackends,
            recommendedModelSize: tier.recommendedModelSize,
            benchmarkDate: Date()
        )
    }

    public func quickAssess() async -> Tier {
        let memoryGB = await getMemoryGB()

        if memoryGB < 8 {
            return .minimum
        } else if memoryGB < 16 {
            return memoryGB < 12 ? .minimum : .standard
        } else if memoryGB < 32 {
            return .powerful
        }
        return .extreme
    }

    private func benchmarkCPU() async -> Double {
        let startTime = Date()

        var values = [Int](0..<10000)
        let iterations = 100

        for _ in 0..<iterations {
            values.sort()
            for i in 0..<values.count {
                let j = Int.random(in: 0..<values.count)
                if i < j {
                    values.swapAt(i, j)
                }
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)

        let baseScore: Double = 100
        let maxIterations: Double = Double(iterations) * 0.01

        let normalizedSpeed = maxIterations / max(elapsed, 0.001)
        return min(baseScore * normalizedSpeed, 100)
    }

    private func benchmarkGPU() async -> Double? {
        guard ProcessInfo.processInfo.environment["METAL_DEVICE_SHADER_SUPPORT"] != nil else {
            return nil
        }

        let startTime = Date()

        var result: [Float] = Array(repeating: 0, count: 1000)
        for i in 0..<1000 {
            var value: Float = Float(i)
            for _ in 0..<100 {
                value = sin(cos(sin(value * Float(i))))
            }
            result[i] = value
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let baseScore: Double = 100

        let normalizedSpeed = 1.0 / max(elapsed, 0.001)
        return min(baseScore * normalizedSpeed * 0.1, 100)
    }

    private func benchmarkMemory() async -> Double {
        let memoryInfo = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memoryInfo) / (1024 * 1024 * 1024)

        if memoryGB < 8 {
            return 25
        } else if memoryGB < 16 {
            return 50
        } else if memoryGB < 32 {
            return 75
        } else if memoryGB < 64 {
            return 90
        }
        return 100
    }

    private func benchmarkStorage() async -> Double {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("benchmark_\(UUID().uuidString)")

        let testSize = 100 * 1024 * 1024
        let testData = Data(count: testSize)
        
        let writeStart = Date()
        do {
            try testData.write(to: testFile)
        } catch {
            return 50
        }
        let writeElapsed = Date().timeIntervalSince(writeStart)

        let readStart = Date()
        do {
            let readData = try Data(contentsOf: testFile)
            _ = readData
        } catch {
            try? FileManager.default.removeItem(at: testFile)
            return 50
        }
        let readElapsed = Date().timeIntervalSince(readStart)

        try? FileManager.default.removeItem(at: testFile)

        let totalElapsed = writeElapsed + readElapsed
        let speedMBperS = Double(testSize * 2) / (1024 * 1024) / totalElapsed

        if speedMBperS < 100 {
            return 25
        } else if speedMBperS < 500 {
            return 50
        } else if speedMBperS < 2000 {
            return 75
        }
        return 100
    }

    private func getMemoryGB() async -> Int {
        let memoryInfo = ProcessInfo.processInfo.physicalMemory
        return Int(Double(memoryInfo) / (1024 * 1024 * 1024))
    }

    private func calculateOverallScore(
        cpu: Double,
        gpu: Double?,
        memory: Double,
        storage: Double
    ) -> Double {
        var weights: [Double: Double] = [
            cpu: 0.40,
            memory: 0.35,
            storage: 0.25
        ]

        var score = cpu * weights[cpu]! + memory * weights[memory]! + storage * weights[storage]!

        if let gpu = gpu {
            weights[gpu] = 0.30
            weights[cpu] = 0.30
            weights[memory] = 0.25
            weights[storage] = 0.15
            score = cpu * weights[cpu]! + (gpu * 0.30) + memory * weights[memory]! + storage * weights[storage]!
        }

        return min(score, 100)
    }

    private func determineTier(from overallScore: Double, gpuScore: Double?, memoryGB: Int) -> Tier {
        if overallScore < 35 || memoryGB < 8 {
            return .minimum
        } else if overallScore < 60 || memoryGB < 16 {
            return .standard
        } else if overallScore < 80 || memoryGB < 32 {
            return .powerful
        }
        return .extreme
    }

    private func determineBackends(gpuScore: Double?, tier: Tier) -> [SystemMLBackend] {
        var backends: [SystemMLBackend] = []

        if gpuScore != nil && gpuScore! > 30 {
            backends.append(.mlx)
            backends.append(.coreml)
        }

        switch tier {
        case .minimum:
            backends.insert(.gguf, at: 0)
        case .standard:
            if !backends.contains(.mlx) {
                backends.insert(.mlx, at: 0)
            }
            backends.append(.gguf)
        case .powerful, .extreme:
            backends.insert(.mlx, at: 0)
            backends.append(.gguf)
            backends.append(.safetensors)
        }

        return backends
    }
}

public struct BenchmarkTask: Identifiable, Sendable {
    public let id: String
    public let name: String
    public var status: TaskStatus
    public var progress: Double
    public var result: Double?

    public enum TaskStatus: String, Sendable {
        case pending
        case running
        case completed
        case failed
    }
}

public actor BenchmarkRunner {
    private var tasks: [String: BenchmarkTask] = [:]
    private let benchmark: SystemBenchmark

    public init(benchmark: SystemBenchmark = SystemBenchmark()) {
        self.benchmark = benchmark
    }

    public func startBenchmark() async -> [BenchmarkTask] {
        tasks["cpu"] = BenchmarkTask(id: "cpu", name: "CPU Performance", status: .running, progress: 0, result: nil)
        tasks["gpu"] = BenchmarkTask(id: "gpu", name: "GPU Performance", status: .pending, progress: 0, result: nil)
        tasks["memory"] = BenchmarkTask(id: "memory", name: "Memory", status: .pending, progress: 0, result: nil)
        tasks["storage"] = BenchmarkTask(id: "storage", name: "Storage Speed", status: .pending, progress: 0, result: nil)

        return Array(tasks.values)
    }

    public func getTasks() -> [BenchmarkTask] {
        Array(tasks.values)
    }
}
