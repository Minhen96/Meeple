package com.meeplehearth.social.dto;

import java.util.UUID;

/**
 * A "people you may know" row (FEATURES_COMPLETE 2.3). Suggestions never include friends or users
 * with a pending request either way, so there is no friendship status.
 *
 * @param sharedGames how many games in the viewer's collection this user also has
 */
public record SuggestedUser(UUID id, String username, String displayName, String avatarUrl, long sharedGames) {
}
