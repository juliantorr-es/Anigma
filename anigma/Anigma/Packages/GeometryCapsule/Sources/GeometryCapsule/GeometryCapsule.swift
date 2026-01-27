/// GeometryCapsule.swift
/// Public API for GeometryCapsule
/// Tier 1: 3D geometry operations with spatial calculations and transformations
///
/// This file provides:
/// - Contract 1: CapsuleError for all public failures
/// - Contract 2: CapsuleDiagnostics for observability
/// - Sendable compliance (Swift 6)
/// - 3D geometry operations
/// - Spatial calculations
/// - Transformations

import Foundation
import CapsuleCore
import TelemetryCore

/// The GeometryCapsule public API
/// 3D geometry operations with spatial calculations and transformations
public final class GeometryCapsule: Sendable {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Diagnostics for observability (correlation ID tracking, span timing)
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation (separated for clarity)
    private nonisolated let impl: GeometryCapsuleInternal
    
    /// Initialize a GeometryCapsule instance
    /// - Parameters:
    ///   - id: Unique identifier for this capsule (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if id is empty or invalid
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        // Validate configuration (Contract 1 gate)
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Capsule ID cannot be empty")
        }
        
        self.id = id
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.impl = GeometryCapsuleInternal()
        
        // Emit initialization event
        let span = self.diagnostics.beginSpan(
            name: "GeometryCapsule.init",
            category: "initialization",
            correlationID: nil,
            tags: ["capsule_id": id]
        )
        span.end(status: .ok)
    }
    
    /// Calculate distance between two 3D points
    /// - Parameters:
    ///   - point1: First point
    ///   - point2: Second point
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Distance between points
    /// - Throws: `CapsuleError` variants for calculation failures
    public func calculateDistance(
        from point1: Point3D,
        to point2: Point3D,
        correlationID: String? = nil
    ) async throws -> Double {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "GeometryCapsule.calculateDistance",
            category: "distance_calculation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "point1": "(\(point1.x),\(point1.y),\(point1.z))",
                "point2": "(\(point2.x),\(point2.y),\(point2.z))"
            ]
        )
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "geometrycapsule.calculateDistance",
            message: "Calculating distance between points",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        let distance = impl.distance(from: point1, to: point2)
        
        // Success event
        diagnostics.event(
            level: .info,
            category: "geometrycapsule.calculateDistance",
            message: "Distance calculation completed",
            correlationID: corrID,
            metadata: ["distance": "\(distance)"]
        )
        
        span.end(status: .ok)
        return distance
    }
    
    /// Apply transformation to a 3D point
    /// - Parameters:
    ///   - point: Point to transform
    ///   - transform: Transformation to apply
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Transformed point
    /// - Throws: `CapsuleError` variants for transformation failures
    public func transformPoint(
        _ point: Point3D,
        with transform: Transform3D,
        correlationID: String? = nil
    ) async throws -> Point3D {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "GeometryCapsule.transformPoint",
            category: "point_transformation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "point": "(\(point.x),\(point.y),\(point.z))"
            ]
        )
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "geometrycapsule.transformPoint",
            message: "Transforming point",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let transformedPoint = impl.transformPoint(point, with: transform)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "geometrycapsule.transformPoint",
                message: "Point transformation completed",
                correlationID: corrID,
                metadata: [
                    "result": "(\(transformedPoint.x),\(transformedPoint.y),\(transformedPoint.z))"
                ]
            )
            
            span.end(status: .ok)
            return transformedPoint
        } catch let geometryError as GeometryError {
            // Map Geometry errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "geometrycapsule.transformPoint",
                message: "Point transformation failed: \(geometryError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "GeometryError"]
            )
            span.end(status: .error)
            
            switch geometryError {
            case .invalidGeometry, .transformationFailed:
                throw CapsuleError.invalidInput(field: "geometry", constraint: geometryError.localizedDescription)
            case .calculationFailed:
                throw CapsuleError.internalError(details: geometryError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Apply transformation to a triangle mesh
    /// - Parameters:
    ///   - mesh: Mesh to transform
    ///   - transform: Transformation to apply
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Transformed mesh
    /// - Throws: `CapsuleError` variants for transformation failures
    public func transformMesh(
        _ mesh: TriangleMesh,
        with transform: Transform3D,
        correlationID: String? = nil
    ) async throws -> TriangleMesh {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "GeometryCapsule.transformMesh",
            category: "mesh_transformation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "vertex_count": "\(mesh.vertices.count)",
                "triangle_count": "\(mesh.indices.count / 3)"
            ]
        )
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "geometrycapsule.transformMesh",
            message: "Transforming triangle mesh",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let transformedMesh = impl.transformMesh(mesh, with: transform)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "geometrycapsule.transformMesh",
                message: "Mesh transformation completed",
                correlationID: corrID,
                metadata: [
                    "result_vertices": "\(transformedMesh.vertices.count)"
                ]
            )
            
            span.end(status: .ok)
            return transformedMesh
        } catch let geometryError as GeometryError {
            // Map Geometry errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "geometrycapsule.transformMesh",
                message: "Mesh transformation failed: \(geometryError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "GeometryError"]
            )
            span.end(status: .error)
            
            switch geometryError {
            case .invalidGeometry, .transformationFailed:
                throw CapsuleError.invalidInput(field: "mesh", constraint: geometryError.localizedDescription)
            case .calculationFailed:
                throw CapsuleError.internalError(details: geometryError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Calculate bounding box for a set of points
    /// - Parameters:
    ///   - points: Array of 3D points
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Bounding box containing all points
    /// - Throws: `CapsuleError` variants for calculation failures
    public func calculateBoundingBox(
        for points: [Point3D],
        correlationID: String? = nil
    ) async throws -> BoundingBox3D {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "GeometryCapsule.calculateBoundingBox",
            category: "bounding_box_calculation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "point_count": "\(points.count)"
            ]
        )
        
        // Validation
        guard !points.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "points",
                constraint: "Non-empty array required"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "geometrycapsule.calculateBoundingBox",
            message: "Calculating bounding box for points",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let boundingBox = impl.calculateBoundingBox(for: points)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "geometrycapsule.calculateBoundingBox",
                message: "Bounding box calculation completed",
                correlationID: corrID,
                metadata: [
                    "volume": "\(boundingBox.volume)"
                ]
            )
            
            span.end(status: .ok)
            return boundingBox
        } catch let geometryError as GeometryError {
            // Map Geometry errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "geometrycapsule.calculateBoundingBox",
                message: "Bounding box calculation failed: \(geometryError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "GeometryError"]
            )
            span.end(status: .error)
            
            switch geometryError {
            case .invalidGeometry:
                throw CapsuleError.invalidInput(field: "points", constraint: geometryError.localizedDescription)
            case .calculationFailed, .transformationFailed:
                throw CapsuleError.internalError(details: geometryError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Check if two bounding boxes intersect
    /// - Parameters:
    ///   - box1: First bounding box
    ///   - box2: Second bounding box
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: True if boxes intersect
    /// - Throws: `CapsuleError` variants for calculation failures
    public func checkIntersection(
        between box1: BoundingBox3D,
        and box2: BoundingBox3D,
        correlationID: String? = nil
    ) async throws -> Bool {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "GeometryCapsule.checkIntersection",
            category: "intersection_check",
            correlationID: corrID,
            tags: [
                "capsule_id": id
            ]
        )
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "geometrycapsule.checkIntersection",
            message: "Checking bounding box intersection",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let intersects = impl.boundingBoxesIntersect(box1, box2)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "geometrycapsule.checkIntersection",
                message: "Intersection check completed",
                correlationID: corrID,
                metadata: [
                    "result": "\(intersects)"
                ]
            )
            
            span.end(status: .ok)
            return intersects
        } catch let geometryError as GeometryError {
            // Map Geometry errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "geometrycapsule.checkIntersection",
                message: "Intersection check failed: \(geometryError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "GeometryError"]
            )
            span.end(status: .error)
            
            switch geometryError {
            case .invalidGeometry:
                throw CapsuleError.invalidInput(field: "boxes", constraint: geometryError.localizedDescription)
            case .calculationFailed, .transformationFailed:
                throw CapsuleError.internalError(details: geometryError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Calculate volume of a triangle mesh
    /// - Parameters:
    ///   - mesh: Triangle mesh
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Volume of mesh
    /// - Throws: `CapsuleError` variants for calculation failures
    public func calculateMeshVolume(
        _ mesh: TriangleMesh,
        correlationID: String? = nil
    ) async throws -> Double {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "GeometryCapsule.calculateMeshVolume",
            category: "volume_calculation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "vertex_count": "\(mesh.vertices.count)"
            ]
        )
        
        // Validation
        guard !mesh.vertices.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "mesh.vertices",
                constraint: "Non-empty array required"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "geometrycapsule.calculateMeshVolume",
            message: "Calculating mesh volume",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let volume = impl.calculateMeshVolume(mesh)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "geometrycapsule.calculateMeshVolume",
                message: "Mesh volume calculation completed",
                correlationID: corrID,
                metadata: [
                    "volume": "\(volume)"
                ]
            )
            
            span.end(status: .ok)
            return volume
        } catch let geometryError as GeometryError {
            // Map Geometry errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "geometrycapsule.calculateMeshVolume",
                message: "Volume calculation failed: \(geometryError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "GeometryError"]
            )
            span.end(status: .error)
            
            switch geometryError {
            case .invalidGeometry:
                throw CapsuleError.invalidInput(field: "mesh", constraint: geometryError.localizedDescription)
            case .calculationFailed, .transformationFailed:
                throw CapsuleError.internalError(details: geometryError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get capsule health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "capsule_id": id,
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
/// Can be replaced with actual daemon diagnostics when integrated
internal final class MockDiagnostics: CapsuleDiagnostics {
    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        MockDiagnosticSpan()
    }
    
    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // In tests, diagnostics are collected for assertions
    }
    
    public func getEvents(since: Date) -> [DiagnosticEvent] {
        []
    }
    
    public func getAllEvents() -> [DiagnosticEvent] {
        []
    }
    
    public func clearEvents() {
        // noop
    }
}

internal final class MockDiagnosticSpan: DiagnosticSpan {
    let spanID = UUID().uuidString
    let name = "mock"
    let category = "mock"
    let correlationID = UUID().uuidString
    let startTime = Date()
    
    var endTime: Date? { nil }
    var duration: TimeInterval? { nil }
    var status: SpanStatus? { nil }
    var tags: [String: String] { [:] }
    
    func end(status: SpanStatus) { }
    func addTag(key: String, value: String) { }
    func recordEvent(level: DiagnosticLevel, message: String) { }
}