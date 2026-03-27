package com.meeplehearth.game.client;

import org.springframework.stereotype.Component;

// TODO: Implement BGG XML API v2 calls using WebClient
// Wrap with Resilience4j circuit breaker — never call BGG without it
// Endpoints: /xmlapi2/search?query=&type=boardgame, /xmlapi2/thing?id=&stats=1
@Component
public class BggApiClient {
}
