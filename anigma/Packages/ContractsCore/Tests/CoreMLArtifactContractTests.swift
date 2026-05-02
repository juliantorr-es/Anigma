//
//  CoreMLArtifactContractTests.swift
//  ContractsCoreTests
//
//  Tests for CoreMLArtifactContract and its 5 SURFACE layers
//

import Testing
import Foundation
@testable import ContractsCore

@Test("CoreMLArtifactContract should validate all 5 SURFACE layers")
func testCoreMLArtifactContractValidation() async throws {
    // Create a valid CoreML artifact
    let schema = CoreMLSchema(
        description: "Test MobileNetV2 model",
        inputs: [
            IOTensorSpec(
                name: "input",
                dataType: .float32,
                shape: TensorShape(batch: 1, channels: 3, height: 224, width: 224),
                coordinateSystem: CoordinateSystem(origin: .topLeft, normalization: .imagenet)
            )
        ],
        outputs: [
            IOTensorSpec(
                name: "output",
                dataType: .float32,
                shape: TensorShape(batch: 1, channels: 1000, height: 1, width: 1)
            )
        ],
        modelType: "classifier",
        classLabels: (0..<1000).map { "class_\($0)" }
    )
    
    let limits = CoreMLLimits(
        hard: HardLimits(
            maxBatchSize: 4,
            maxMemoryBytes: 256 * 1024 * 1024, // 256MB
            maxInferenceTimeMs: 1000,
            maxModelSizeBytes: 50 * 1024 * 1024, // 50MB
            maxInputSizeBytes: 10 * 1024 * 1024, // 10MB
            maxOutputSizeBytes: 4 * 1024 * 1024 // 4MB
        ),
        soft: SoftLimits(
            recommendedBatchSize: 1,
            targetMemoryBytes: 128 * 1024 * 1024, // 128MB
            targetInferenceTimeMs: 500,
            memoryWarningThreshold: 0.8,
            timeWarningThreshold: 0.8
        )
    )
    
    let versioning = CoreMLVersion(
        semantic: "1.0.0",
        build: "20240101",
        architectureFingerprint: ArchitectureFingerprint(
            architecture: "MobileNetV2",
            opsetVersion: "coremltools5",
            coremlVersion: "5.0",
            compilerVersion: "coremltools==5.0",
            quantization: "float16"
        )
    )
    
    let capability = CoreMLCapability(
        hardwareCapability: .mixed,
        performanceProfiles: [
            PerformanceProfile(
                hardware: "ANE",
                expectedInferenceTimeMs: 50,
                expectedMemoryBytes: 64 * 1024 * 1024,
                powerEstimateMw: 500,
                thermalImpact: 3
            ),
            PerformanceProfile(
                hardware: "CPU",
                expectedInferenceTimeMs: 200,
                expectedMemoryBytes: 128 * 1024 * 1024,
                thermalImpact: 5
            )
        ],
        requiredFeatures: ["ANE17"],
        minOSVersion: "14.0",
        minCoreMLVersion: "5.0"
    )
    
    let artifact = CoreMLArtifact(
        artifactId: "test_artifact_hash",
        modelHash: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567",
        schema: schema,
        limits: limits,
        versioning: versioning,
        capability: capability,
        receipts: CoreMLReceipts(),
        metadata: ["purpose": "testing"]
    )
    
    let contract = CoreMLArtifactContract(artifact)
    
    // Should not throw for valid artifact
    try #require(try CoreMLArtifactContract.validateInvariants(contract))
}

@Test("CoreMLArtifactContract should reject invalid schema")
func testInvalidSchemaValidation() async throws {
    // Create artifact with invalid schema (empty inputs)
    let invalidSchema = CoreMLSchema(
        description: "Invalid model",
        inputs: [],
        outputs: [
            IOTensorSpec(
                name: "output",
                dataType: .float32,
                shape: TensorShape(batch: 1, channels: 1000, height: 1, width: 1)
            )
        ],
        modelType: "classifier"
    )
    
    let artifact = CoreMLArtifact(
        artifactId: "test_hash",
        modelHash: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567",
        schema: invalidSchema,
        limits: CoreMLLimits(
            hard: HardLimits(
                maxBatchSize: 1,
                maxMemoryBytes: 100 * 1024 * 1024,
                maxInferenceTimeMs: 1000,
                maxModelSizeBytes: 10 * 1024 * 1024,
                maxInputSizeBytes: 1 * 1024 * 1024,
                maxOutputSizeBytes: 1 * 1024 * 1024
            ),
            soft: SoftLimits(
                recommendedBatchSize: 1,
                targetMemoryBytes: 50 * 1024 * 1024,
                targetInferenceTimeMs: 500
            )
        ),
        versioning: CoreMLVersion(
            semantic: "1.0.0",
            build: "test",
            architectureFingerprint: ArchitectureFingerprint(
                architecture: "Test",
                opsetVersion: "1",
                coremlVersion: "1.0",
                compilerVersion: "1.0"
            )
        ),
        capability: CoreMLCapability(
            hardwareCapability: .cpuOnly,
            performanceProfiles: [
                PerformanceProfile(
                    hardware: "CPU",
                    expectedInferenceTimeMs: 100,
                    expectedMemoryBytes: 50 * 1024 * 1024
                )
            ]
        )
    )
    
    let contract = CoreMLArtifactContract(artifact)
    
    // Should throw validation error
    try #require(throws: ValidationError.self) {
        try CoreMLArtifactContract.validateInvariants(contract)
    }
}

@Test("TensorShape validation should work correctly")
func testTensorShapeValidation() async throws {
    // Valid shape
    let validShape = TensorShape(batch: 1, channels: 3, height: 224, width: 224)
    try #require(try validShape.validate())
    
    // Invalid shape (negative channels)
    let invalidShape = TensorShape(batch: 1, channels: -1, height: 224, width: 224)
    try #require(throws: ValidationError.self) {
        try invalidShape.validate()
    }
}

@Test("HardwareCapability should correctly check support")
func testHardwareCapabilitySupport() async throws {
    let aneOnly = HardwareCapability.aneOnly
    #expect(aneOnly.supports("ANE"))
    #expect(!aneOnly.supports("CPU"))
    #expect(!aneOnly.supports("GPU"))
    
    let mixed = HardwareCapability.mixed
    #expect(mixed.supports("ANE"))
    #expect(mixed.supports("CPU"))
    #expect(mixed.supports("GPU"))
    
    let cpuOnly = HardwareCapability.cpuOnly
    #expect(!cpuOnly.supports("ANE"))
    #expect(cpuOnly.supports("CPU"))
    #expect(!cpuOnly.supports("GPU"))
}

@Test("Schema hash should be deterministic")
func testSchemaHashDeterministic() async throws {
    let schema1 = CoreMLSchema(
        description: "Test model",
        inputs: [
            IOTensorSpec(
                name: "input1",
                dataType: .float32,
                shape: TensorShape(channels: 3, height: 224, width: 224)
            )
        ],
        outputs: [
            IOTensorSpec(
                name: "output1",
                dataType: .float32,
                shape: TensorShape(channels: 1000, height: 1, width: 1)
            )
        ],
        modelType: "classifier"
    )
    
    let schema2 = CoreMLSchema(
        description: "Test model",
        inputs: [
            IOTensorSpec(
                name: "input1",
                dataType: .float32,
                shape: TensorShape(channels: 3, height: 224, width: 224)
            )
        ],
        outputs: [
            IOTensorSpec(
                name: "output1",
                dataType: .float32,
                shape: TensorShape(channels: 1000, height: 1, width: 1)
            )
        ],
        modelType: "classifier"
    )
    
    #expect(schema1.schemaHash == schema2.schemaHash)
    
    // Different schema should have different hash
    let schema3 = CoreMLSchema(
        description: "Different model",
        inputs: [
            IOTensorSpec(
                name: "input1",
                dataType: .float32,
                shape: TensorShape(channels: 3, height: 224, width: 224)
            )
        ],
        outputs: [
            IOTensorSpec(
                name: "output1",
                dataType: .float32,
                shape: TensorShape(channels: 1000, height: 1, width: 1)
            )
        ],
        modelType: "classifier"
    )
    
    #expect(schema1.schemaHash != schema3.schemaHash)
}

@Test("Artifact hash should include all relevant components")
func testArtifactHashComputation() async throws {
    let artifact1 = CoreMLArtifact(
        artifactId: "test",
        modelHash: "hash1",
        schema: CoreMLSchema(
            description: "Test",
            inputs: [IOTensorSpec(name: "in", dataType: .float32, shape: TensorShape(channels: 1, height: 1, width: 1))],
            outputs: [IOTensorSpec(name: "out", dataType: .float32, shape: TensorShape(channels: 1, height: 1, width: 1))],
            modelType: "test"
        ),
        limits: CoreMLLimits(
            hard: HardLimits(
                maxBatchSize: 1,
                maxMemoryBytes: 1000,
                maxInferenceTimeMs: 1000,
                maxModelSizeBytes: 1000,
                maxInputSizeBytes: 1000,
                maxOutputSizeBytes: 1000
            ),
            soft: SoftLimits(
                recommendedBatchSize: 1,
                targetMemoryBytes: 500,
                targetInferenceTimeMs: 500
            )
        ),
        versioning: CoreMLVersion(
            semantic: "1.0.0",
            build: "build1",
            architectureFingerprint: ArchitectureFingerprint(
                architecture: "Test",
                opsetVersion: "1",
                coremlVersion: "1.0",
                compilerVersion: "1.0"
            )
        ),
        capability: CoreMLCapability(
            hardwareCapability: .cpuOnly,
            performanceProfiles: [
                PerformanceProfile(
                    hardware: "CPU",
                    expectedInferenceTimeMs: 100,
                    expectedMemoryBytes: 500
                )
            ]
        ),
        metadata: ["key": "value"]
    )
    
    let artifact2 = CoreMLArtifact(
        artifactId: "test",
        modelHash: "hash1",
        schema: CoreMLSchema(
            description: "Test",
            inputs: [IOTensorSpec(name: "in", dataType: .float32, shape: TensorShape(channels: 1, height: 1, width: 1))],
            outputs: [IOTensorSpec(name: "out", dataType: .float32, shape: TensorShape(channels: 1, height: 1, width: 1))],
            modelType: "test"
        ),
        limits: CoreMLLimits(
            hard: HardLimits(
                maxBatchSize: 1,
                maxMemoryBytes: 1000,
                maxInferenceTimeMs: 1000,
                maxModelSizeBytes: 1000,
                maxInputSizeBytes: 1000,
                maxOutputSizeBytes: 1000
            ),
            soft: SoftLimits(
                recommendedBatchSize: 1,
                targetMemoryBytes: 500,
                targetInferenceTimeMs: 500
            )
        ),
        versioning: CoreMLVersion(
            semantic: "1.0.0",
            build: "build1",
            architectureFingerprint: ArchitectureFingerprint(
                architecture: "Test",
                opsetVersion: "1",
                coremlVersion: "1.0",
                compilerVersion: "1.0"
            )
        ),
        capability: CoreMLCapability(
            hardwareCapability: .cpuOnly,
            performanceProfiles: [
                PerformanceProfile(
                    hardware: "CPU",
                    expectedInferenceTimeMs: 100,
                    expectedMemoryBytes: 500
                )
            ]
        ),
        metadata: ["key": "value"]
    )
    
    #expect(artifact1.artifactHash == artifact2.artifactHash)
    
    // Different metadata should produce different hash
    let artifact3 = CoreMLArtifact(
        artifactId: "test",
        modelHash: "hash1",
        schema: CoreMLSchema(
            description: "Test",
            inputs: [IOTensorSpec(name: "in", dataType: .float32, shape: TensorShape(channels: 1, height: 1, width: 1))],
            outputs: [IOTensorSpec(name: "out", dataType: .float32, shape: TensorShape(channels: 1, height: 1, width: 1))],
            modelType: "test"
        ),
        limits: CoreMLLimits(
            hard: HardLimits(
                maxBatchSize: 1,
                maxMemoryBytes: 1000,
                maxInferenceTimeMs: 1000,
                maxModelSizeBytes: 1000,
                maxInputSizeBytes: 1000,
                maxOutputSizeBytes: 1000
            ),
            soft: SoftLimits(
                recommendedBatchSize: 1,
                targetMemoryBytes: 500,
                targetInferenceTimeMs: 500
            )
        ),
        versioning: CoreMLVersion(
            semantic: "1.0.0",
            build: "build1",
            architectureFingerprint: ArchitectureFingerprint(
                architecture: "Test",
                opsetVersion: "1",
                coremlVersion: "1.0",
                compilerVersion: "1.0"
            )
        ),
        capability: CoreMLCapability(
            hardwareCapability: .cpuOnly,
            performanceProfiles: [
                PerformanceProfile(
                    hardware: "CPU",
                    expectedInferenceTimeMs: 100,
                    expectedMemoryBytes: 500
                )
            ]
        ),
        metadata: ["key": "different_value"]  // Different metadata
    )
    
    #expect(artifact1.artifactHash != artifact3.artifactHash)
}