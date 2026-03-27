package com.meeplehearth.ai.service;

import org.springframework.stereotype.Service;

// Phase 3 — RAG pipeline:
// 1. Embed user question with text-embedding-3-small
// 2. pgvector similarity search on game_rules table
// 3. Build prompt with retrieved chunks + last 3 conversation turns
// 4. Call gpt-4o-mini for completion
// Must be wrapped with Resilience4j circuit breaker on OpenAI calls
@Service
public class AiService {
}
