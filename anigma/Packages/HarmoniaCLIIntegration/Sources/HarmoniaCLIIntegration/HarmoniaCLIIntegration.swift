// HarmoniaCLIIntegration.swift
//
// Created as part of td-640a4f: Reduce HarmoniaModule fan-out from 34 to < 15 dependencies
// This module provides CLI-specific integrations for Harmonia functionality
//
// Purpose: Separate CLI dependencies from core HarmoniaModule to improve compilation performance
// and reduce dependency bloat. HarmoniaModule should focus on core functionality while
// CLI-specific integrations live in this separate module.

/// HarmoniaCLIIntegration provides CLI-specific functionality that bridges
/// between Harmonia core modules and Anigma CLI infrastructure.
public enum HarmoniaCLIIntegration {
    // This module serves as an integration layer for CLI-specific Harmonia functionality
    // It depends on both HarmoniaModule (for core functionality) and CLI modules
    // (AnigmaCLIProviders, AnigmaCLIRouter, etc.) to provide CLI-specific features
    
    // The empty enum pattern is used to provide a namespace for CLI integration functionality
    // while keeping the module lightweight and focused on its integration purpose.
}

// MARK: - Module Architecture
//
// Dependency Flow:
//   HarmoniaModule (core functionality)
//         ↓
//   HarmoniaCLIIntegration (CLI integration layer)
//         ↓  
//   AnigmaCLI* modules (CLI infrastructure)
//
// This separation reduces HarmoniaModule's fan-out from 34 to 29 dependencies
// and establishes a clear layering between core and CLI-specific functionality.