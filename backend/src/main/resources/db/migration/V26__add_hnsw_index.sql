-- HNSW vector index for pgvector similarity search on game_rules.embedding
-- HNSW chosen over ivfflat: no training required, works on empty tables (important for Neon)
-- m=16 ef_construction=64 are pgvector defaults — good balance for this dataset size
CREATE INDEX idx_game_rules_embedding_hnsw ON game_rules
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);
