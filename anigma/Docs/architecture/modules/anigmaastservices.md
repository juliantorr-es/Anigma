# AnigmaASTServices

## Overview

AnigmaASTServices is a Swift module in the Anigma ecosystem with **2231 lines of code** across **8 files**.

## Statistics

- **Public Types**: 29
- **Public Functions**: 18  
- **Components**: 0
- **Systems**: 0
- **Services**: 0

## Architecture

### Components
No components found

### Systems
No systems found

### Services
No services found

## Dependencies

- `AnigmaPrimitives`

## File Structure


### ASTFacade.swift

- **Lines**: 318
- **Public Types**: 9
- **Public Functions**: 9


**Public Types:**
- `struct ASTNode` (line 16)
- `struct ParsedSource` (line 24)
- `struct ASTParser` (line 39)
- `protocol ASTVisitor` (line 63)
- `class SecurityPatternVisitor` (line 70)
- `class AuthenticationPatternVisitor` (line 124)
- `class ComplexityVisitor` (line 172)
- `class ConcurrencyVisitor` (line 229)
- `class ArchitectureVisitor` (line 287)



**Public Functions:**
- `parse` (static) (line 42)
- `lineNumber` (static) (line 48)
- `columnNumber` (static) (line 54)
- `getViolations` (line 118)
- `getViolations` (line 166)
- `getMaxLoopDepth` (line 219)
- `getViolations` (line 223)
- `getViolations` (line 281)
- `getViolations` (line 315)


### AddSendableToValueTypesRule.swift

- **Lines**: 211
- **Public Types**: 0
- **Public Functions**: 1




**Public Functions:**
- `apply` (line 19)


### AgSearchService.swift

- **Lines**: 410
- **Public Types**: 3
- **Public Functions**: 2


**Public Types:**
- `struct SearchResult` (line 19)
- `struct SearchConfig` (line 42)
- `enum SwiftPattern` (line 386)



**Public Functions:**
- `search` (line 83)
- `clearCache` (line 121)


### AnigmaASTServices.swift

- **Lines**: 13
- **Public Types**: 0
- **Public Functions**: 0





### RewritePipeline.swift

- **Lines**: 606
- **Public Types**: 8
- **Public Functions**: 1


**Public Types:**
- `struct PipelineConfig` (line 13)
- `enum LogLevel` (line 35)
- `enum PipelineError` (line 43)
- `struct VerificationOutcome` (line 63)
- `struct PipelineResult` (line 73)
- `struct PipelineItem` (line 105)
- `struct FileOutcome` (line 115)
- `enum Status` (line 116)



**Public Functions:**
- `execute` (line 192)


### RewriteRule.swift

- **Lines**: 351
- **Public Types**: 7
- **Public Functions**: 0


**Public Types:**
- `struct RewriteResult` (line 21)
- `struct SourceChange` (line 45)
- `struct RuleExample` (line 77)
- `protocol RewriteRule` (line 97)
- `protocol AstAnchoredRule` (line 118)
- `enum RuleValidationError` (line 320)
- `enum RuleApplicationError` (line 338)




### SwiftAstLens.swift

- **Lines**: 307
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `struct AstLocation` (line 22)
- `enum AstError` (line 279)



**Public Functions:**
- `ast` (line 84)
- `findNodes` (line 114)
- `findNodes` (line 137)
- `clearCache` (line 148)
- `cacheStats` (line 163)


### main.swift

- **Lines**: 15
- **Public Types**: 0
- **Public Functions**: 0





