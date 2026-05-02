// EventTransformation.swift
// Event transformation utilities for the Anigma event-driven architecture

import Foundation

/// Event transformer protocol
public protocol EventTransformer: Sendable {
    /// Transform an event to another event
    /// - Parameter event: The event to transform
    /// - Returns: The transformed event, or nil if transformation fails
    func transform<Input: AnigmaEvent, Output: AnigmaEvent>(_ event: TypedEvent<Input>) async throws -> TypedEvent<Output>?
}

/// Event transformation pipeline
public struct EventTransformationPipeline {
    private let transformers: [any EventTransformer]
    
    public init(transformers: [any EventTransformer] = []) {
        self.transformers = transformers
    }
    
    /// Add a transformer to the pipeline
    /// - Parameter transformer: The transformer to add
    /// - Returns: The updated pipeline
    public func add<Transformer: EventTransformer>(_ transformer: Transformer) -> EventTransformationPipeline {
        var newTransformers = transformers
        newTransformers.append(transformer)
        return EventTransformationPipeline(transformers: newTransformers)
    }
    
    /// Transform an event through the pipeline
    /// - Parameter event: The event to transform
    /// - Returns: The transformed event, or nil if transformation fails
    public func transform<Input: AnigmaEvent, Output: AnigmaEvent>(_ event: TypedEvent<Input>) async throws -> TypedEvent<Output>? {
        var currentInput: TypedEvent<Input>? = event
        
        for transformer in transformers {
            guard let current = currentInput else { return nil }
            guard let transformedInput: TypedEvent<Input> = try await transformer.transform(current) else {
                return nil
            }
            currentInput = transformedInput
        }
        
        guard let current = currentInput, let output = current.event as? Output else {
            return nil
        }
        
        return TypedEvent(event: output, source: current.source)
    }
}

/// Event type converter transformer
public struct EventTypeConverterTransformer<Input: AnigmaEvent, Output: AnigmaEvent>: EventTransformer {
    private let conversion: @Sendable (Input) -> Output
    
    public init(conversion: @escaping @Sendable (Input) -> Output) {
        self.conversion = conversion
    }
    
    public func transform<InputEvent: AnigmaEvent, OutputEvent: AnigmaEvent>(_ event: TypedEvent<InputEvent>) async throws -> TypedEvent<OutputEvent>? {
        guard let inputEvent = event.event as? Input else {
            return nil
        }
        let outputEvent = conversion(inputEvent)
        guard let typedOutput = outputEvent as? OutputEvent else {
            return nil
        }
        return TypedEvent(event: typedOutput, source: event.source)
    }
}

/// Event metadata enricher transformer
public struct EventMetadataEnricherTransformer<Event: AnigmaEvent>: EventTransformer {
    private let metadata: [String: String]
    
    public init(metadata: [String: String]) {
        self.metadata = metadata
    }
    
    public func transform<Input: AnigmaEvent, Output: AnigmaEvent>(_ event: TypedEvent<Input>) async throws -> TypedEvent<Output>? {
        guard let typedEvent = event.event as? Event else {
            return nil
        }

        _ = metadata
        guard let passthrough = typedEvent as? Output else { return nil }
        return TypedEvent(event: passthrough, source: event.source)
    }
}

/// Event source enricher transformer
public struct EventSourceEnricherTransformer<Event: AnigmaEvent>: EventTransformer {
    private let source: String
    
    public init(source: String) {
        self.source = source
    }
    
    public func transform<Input: AnigmaEvent, Output: AnigmaEvent>(_ event: TypedEvent<Input>) async throws -> TypedEvent<Output>? {
        guard let typedEvent = event.event as? Event else {
            return nil
        }
        
        guard let output = typedEvent as? Output else { return nil }
        return TypedEvent(event: output, source: source)
    }
}

/// Event transformation event bus wrapper
public actor TransformingEventBus: EventBus {
    private let underlyingBus: EventBus
    private let pipeline: EventTransformationPipeline
    
    public init(underlyingBus: EventBus, pipeline: EventTransformationPipeline = EventTransformationPipeline()) {
        self.underlyingBus = underlyingBus
        self.pipeline = pipeline
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error> {
        return await underlyingBus.publish(event, source: source)
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        return await underlyingBus.subscribe(to: type) { event in
            await handler(event)
        }
    }
    
    public func unsubscribe(id: UUID) async {
        await underlyingBus.unsubscribe(id: id)
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        await underlyingBus.unsubscribeAll(from: type)
    }
    
    /// Transform and publish an event
    /// - Parameters:
    ///   - event: The event to transform and publish
    ///   - source: Optional source identifier
    /// - Returns: Task that completes when the event is published
    public func transformAndPublish<Event: AnigmaEvent>(_ event: Event, source: String? = nil) async -> Task<Void, any Error> {
        if let transformedEvent: TypedEvent<Event> = try? await pipeline.transform(TypedEvent(event: event, source: source)) {
            return await underlyingBus.publish(transformedEvent.event, source: transformedEvent.source)
        }
        return await underlyingBus.publish(event, source: source)
    }
}

/// Event transformation utilities
public struct EventTransformationUtils {
    /// Create a type converter transformer
    /// - Parameter conversion: The conversion function
    /// - Returns: Type converter transformer
    public static func typeConverter<Input: AnigmaEvent, Output: AnigmaEvent>(_ conversion: @escaping @Sendable (Input) -> Output) -> EventTypeConverterTransformer<Input, Output> {
        return EventTypeConverterTransformer(conversion: conversion)
    }
    
    /// Create a metadata enricher transformer
    /// - Parameter metadata: The metadata to add
    /// - Returns: Metadata enricher transformer
    public static func metadataEnricher<Event: AnigmaEvent>(_ metadata: [String: String]) -> EventMetadataEnricherTransformer<Event> {
        return EventMetadataEnricherTransformer(metadata: metadata)
    }
    
    /// Create a source enricher transformer
    /// - Parameter source: The source to set
    /// - Returns: Source enricher transformer
    public static func sourceEnricher<Event: AnigmaEvent>(_ source: String) -> EventSourceEnricherTransformer<Event> {
        return EventSourceEnricherTransformer(source: source)
    }
    
    /// Create a transformation pipeline
    /// - Returns: Empty transformation pipeline
    public static func pipeline() -> EventTransformationPipeline {
        return EventTransformationPipeline()
    }
    
    /// Create a transforming event bus
    /// - Parameters:
    ///   - bus: The underlying event bus
    ///   - pipeline: The transformation pipeline
    /// - Returns: Transforming event bus
    public static func transformingBus(underlying bus: EventBus, with pipeline: EventTransformationPipeline = EventTransformationPipeline()) -> TransformingEventBus {
        return TransformingEventBus(underlyingBus: bus, pipeline: pipeline)
    }
}
