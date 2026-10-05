package com.meeplehearth.ai.service;

import java.util.UUID;

/**
 * Published when a rulebook row has been set to 'ingesting'. Handled by
 * {@link RulebookIngestionService} only AFTER the publishing transaction commits
 * (or immediately when published outside a transaction), on an async thread.
 */
public record RulebookIngestionRequestedEvent(UUID rulebookId) {}
