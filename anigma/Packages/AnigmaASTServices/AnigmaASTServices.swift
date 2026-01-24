//
//  AnigmaASTServices.swift
//  AnigmaASTServices
//
//  AST infrastructure for code analysis and transformation.
//  Contains: SwiftAstLens (AST lookup with caching), RewriteRule protocol,
//  AgSearchService (fast code search prefilter), RewritePipeline.
//
//  This module provides a clean façade over SwiftSyntax to prevent
//  leakage into the broader Harmonia build chain.
//
//  Also provides in-process AST worker API for daemon integration.
//

import Foundation
