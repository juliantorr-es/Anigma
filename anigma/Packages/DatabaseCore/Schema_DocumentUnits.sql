-- Document Units Schema for Anigma
-- Core principle: Every unit is anchored to source artifacts with complete custody chain

-- Document units: The stable identity for content being processed
CREATE TABLE document_units (
    id TEXT PRIMARY KEY,                    -- UUID-based stable identifier
    source_artifact_path TEXT NOT NULL,    -- Path to Accessum artifact containing original bytes
    source_artifact_hash TEXT NOT NULL,    -- SHA256 of source artifact
    
    -- Content representation (what we actually embed/search)
    content_hash TEXT NOT NULL,            -- SHA256 of normalized content
    content_type TEXT NOT NULL,            -- 'text', 'pdf_bytes', 'image', 'email_headers', etc.
    
    -- Chunking boundaries for large content
    chunk_start INTEGER DEFAULT 0,         -- Byte offset in source content
    chunk_end INTEGER,                     -- Byte offset end (NULL for entire content)
    chunk_type TEXT DEFAULT 'full',        -- 'full', 'page', 'paragraph', 'symbol', 'line'
    
    -- Provenance
    acquisition_timestamp INTEGER NOT NULL, -- When was this acquired/ingested
    acquisition_method TEXT NOT NULL,      -- 'filesystem_scan', 'email_import', 'fax_receive', 'build_output'
    processing_version TEXT DEFAULT '1.0', -- Version of processing pipeline
    
    -- Metadata
    file_path TEXT,                        -- Original file path (for reference)
    file_size INTEGER,                     -- Original file size in bytes
    mime_type TEXT,                        -- Detected MIME type
    encoding TEXT,                         -- Text encoding (if applicable)
    
    -- Search optimization
    content_preview TEXT,                  -- First 200 chars for preview
    search_tokens TEXT,                    -- Tokenized content for FTS
    
    -- Timestamps
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Embedding recipes: The exact method used to produce vectors
CREATE TABLE embedding_recipes (
    id TEXT PRIMARY KEY,                    -- Stable recipe identifier
    name TEXT NOT NULL,                    -- Human-readable name
    engine TEXT NOT NULL,                   -- 'mlx', 'llama', 'openai', etc.
    model_hash TEXT NOT NULL,              -- SHA256 of model file/directory
    
    -- Exact configuration used
    argv TEXT NOT NULL,                     -- JSON array of command-line arguments
    options TEXT NOT NULL,                  -- JSON object of processing options
    
    -- Text processing details
    tokenizer_identity TEXT,                -- Tokenizer version/type
    chunking_method TEXT DEFAULT 'fixed',  -- 'fixed', 'semantic', 'paragraph'
    chunk_size INTEGER DEFAULT 1000,       -- Chunk size in characters/tokens
    chunk_overlap INTEGER DEFAULT 200,     -- Overlap between chunks
    normalization_method TEXT,             -- 'l2', 'none', etc.
    pooling_strategy TEXT,                  -- 'mean', 'cls', 'max'
    
    -- Output specifications
    dimensions INTEGER NOT NULL,           -- Vector dimensions
    dtype TEXT DEFAULT 'float32',          -- Data type
    ordering TEXT DEFAULT 'row-major',     -- Memory layout
    
    -- Provenance
    binary_hash TEXT NOT NULL,             -- SHA256 of worker binary
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    
    -- Constraints for consistency
    UNIQUE(engine, model_hash, argv, options)
);

-- Embeddings: Link document units to vectors with recipe provenance
CREATE TABLE embeddings (
    id TEXT PRIMARY KEY,                    -- UUID for this embedding
    document_unit_id TEXT NOT NULL,        -- Foreign key to document_units
    embedding_recipe_id TEXT NOT NULL,      -- Foreign key to embedding_recipes
    
    -- The vector data (stored as blob for efficiency)
    vector_blob BLOB NOT NULL,              -- Raw float32 little-endian bytes
    vector_hash TEXT NOT NULL,              -- SHA256 of vector data for integrity
    
    -- Accessum artifact linkage
    artifact_path TEXT NOT NULL,            -- Path to embedding container artifact
    artifact_hash TEXT NOT NULL,            -- SHA256 of embedding artifact
    
    -- Computed fields for search
    magnitude REAL,                         -- Precomputed vector magnitude for cosine similarity
    
    -- Provenance
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    
    -- Constraints
    FOREIGN KEY (document_unit_id) REFERENCES document_units(id),
    FOREIGN KEY (embedding_recipe_id) REFERENCES embedding_recipes(id),
    UNIQUE(document_unit_id, embedding_recipe_id)
);

-- Full-text search index for content
CREATE VIRTUAL TABLE document_units_fts USING fts5(
    content_preview,
    search_tokens,
    file_path,
    content_type,
    content='document_units',
    content_rowid='rowid'
);

-- Vector similarity search indexes
CREATE INDEX idx_embeddings_document_unit ON embeddings(document_unit_id);
CREATE INDEX idx_embeddings_recipe ON embeddings(embedding_recipe_id);
CREATE INDEX idx_embeddings_magnitude ON embeddings(magnitude);

-- Document lookup indexes
CREATE INDEX idx_document_units_content_hash ON document_units(content_hash);
CREATE INDEX idx_document_units_file_path ON document_units(file_path);
CREATE INDEX idx_document_units_content_type ON document_units(content_type);
CREATE INDEX idx_document_units_acquisition ON document_units(acquisition_timestamp, acquisition_method);