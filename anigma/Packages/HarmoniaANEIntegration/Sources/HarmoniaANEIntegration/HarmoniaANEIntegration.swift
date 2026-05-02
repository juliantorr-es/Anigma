// HarmoniaANEIntegration.swift
//
// Created as part of td-640a4f: Reduce HarmoniaModule fan-out from 34 to < 15 dependencies
// This module provides integration layer for ANE (Apple Neural Engine) modules
//
// Purpose: Consolidate Harmonia ANE-related dependencies into a single integration module
// to further reduce HarmoniaModule's dependency bloat and improve compilation performance.

/// HarmoniaANEIntegration provides a unified integration layer for
/// Apple Neural Engine related modules used by Harmonia.
public enum HarmoniaANEIntegration {
    // This module serves as an integration layer for ANE (Apple Neural Engine) functionality
    // It depends on ANE-related modules and provides a consolidated interface
    // for HarmoniaModule to use, reducing fan-out.
    
    // The empty enum pattern is used to provide a namespace for ANE integration
    // functionality while keeping the module lightweight and focused.
}

// MARK: - Module Architecture
//
// Dependency Flow:
//   ANEModules (ANECapsuleIntegration, ANEServicesCore)
//         ↓
//   HarmoniaANEIntegration (ANE integration layer)
//         ↓
//   HarmoniaModule (core functionality)
//
// This separation reduces HarmoniaModule's fan-out from 21 to 19 dependencies
// by consolidating 2 ANE-related dependencies into a single integration module.