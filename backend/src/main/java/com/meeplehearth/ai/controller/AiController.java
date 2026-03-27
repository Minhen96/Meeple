package com.meeplehearth.ai.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// Phase 3 — POST /api/v1/ai/rules  (RAG + conversation mode)
// Conversation mode: client sends last 3 Q&A pairs with every request
@RestController
@RequestMapping("/api/v1/ai")
public class AiController {
}
