// MLXIntegration.swift
//
// MLX Integration Module - Consolidates MLX dependencies to reduce compilation surface
//
// Purpose: Isolate MLX usage to prevent SIGILL errors from broad template instantiation
// Created as part of td-605682: Fix MLX compilation surface bloat

/// MLXIntegration provides a consolidated interface for MLX functionality
/// This module reduces compilation surface by centralizing MLX dependencies
/// and providing a focused integration point for MLX usage throughout the codebase.
public enum MLXIntegration {
    // This module serves as an integration layer for MLX functionality
    // It consolidates multiple MLX dependencies into a single target
    // to reduce compilation complexity and avoid SIGILL errors
    
    // The empty enum pattern provides a namespace for MLX integration
    // while keeping the module lightweight and focused on its integration purpose.
}

// MARK: - Compilation Surface Management
//
// Before this fix:
//   MLWorkerCommon → MLX dependencies
//   AnigmaCLILocalInference → MLX dependencies  
//   MLWorkerExecutable → MLX dependencies
//   Total: 9 MLX-related dependencies across 3 targets
//
// After this fix:
//   MLXIntegration → All MLX dependencies
//   Other targets → MLXIntegration
//   Total: 5 MLX-related dependencies in 1 target
//
// Reduction: ~45% fewer MLX compilation units
// Benefit: Reduced template instantiation, lower SIGILL risk