# Module Architecture Explorer

Explore the Anigma architecture through interactive visualizations and detailed module information.

<ModuleExplorer />

---

## 🔗 Module Relationship Mapper

Visualize the dependencies and relationships between modules across different layers and categories.

<RelationshipMapper />

---

## 📊 Architecture Overview

### Core Governance Layer

The foundation of Anigma consists of production-hardened, court-safe modules with minimal dependencies:

- **AnigmaPrimitives**: Foundational types and contracts
- **AnigmaCore**: Central ECS framework and governance substrate  
- **DatabaseCore**: Thread-safe SQLite database access
- **ContractsCore**: Universal contract definitions and validation

### Capability Modules

Feature-rich ecosystem modules that provide specialized functionality:

- **AI Governance**: HarmoniaModule for AI-assisted code orchestration
- **Media Processing**: DiaplasionModule and PolytroposModule for document transformation
- **Knowledge Management**: CodexModule for documentation and knowledge bases
- **Education**: TranscriptumModule for academic records management
- **Project Management**: PragmaModule for task and workflow management
- **CRM**: ConexusModule for contact and relationship management
- **Monitoring**: ObservatoriumModule for telemetry and alerting

### Dependency Flow

All capability modules depend on the Core Governance Layer, ensuring consistent security, audit trails, and governance across the entire ecosystem.

## 🎯 Interactive Features

- **Module Explorer**: Browse and filter modules by layer and category
- **Relationship Mapper**: Visualize dependencies and module relationships
- **Detailed Views**: Examine components, dependencies, and purposes
- **Category Filtering**: Focus on specific capability areas

## 🏗️ Architecture Principles

1. **Two-Tier Architecture**: Clear separation between core governance and capability modules
2. **ECS Foundation**: Entity-Component-System pattern throughout all modules
3. **Governance First**: Every module integrates with the governance system
4. **Modular Design**: Self-contained modules with clear boundaries
5. **Production Hardening**: Core modules use minimal external dependencies