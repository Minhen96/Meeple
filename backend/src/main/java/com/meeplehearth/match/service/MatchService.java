package com.meeplehearth.match.service;

import org.springframework.stereotype.Service;

// Phase 2 — matching algorithm: find users who want to play the same game in overlapping time windows
// Uses Redis distributed lock (setIfAbsent) when running as scheduled job
@Service
public class MatchService {
}
