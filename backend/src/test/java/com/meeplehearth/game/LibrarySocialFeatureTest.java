package com.meeplehearth.game;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.config.CacheConfig.CacheNames;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Profile stats, privacy of another user's library, and friend data on game detail. */
class LibrarySocialFeatureTest extends ApiIntegrationTestBase {

    @Autowired private CacheManager cacheManager;

    private void entry(UUID user, UUID game, boolean owned, int plays, Integer rating, String notes) {
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned, play_count, personal_rating, notes)"
                + " VALUES (?, ?, ?, ?, ?, ?)", user, game, owned, plays, rating, notes);
    }

    private UUID namedGame(String name, String... categories) {
        UUID id = game(2, 4);
        jdbc.update("UPDATE games SET name_en = ? WHERE id = ?", name, id);
        if (categories.length > 0) {
            jdbc.update("INSERT INTO game_details (game_id, categories) VALUES (?, ?::text[])", id,
                    "{" + String.join(",", categories) + "}");
        }
        return id;
    }

    private UUID post(UUID author, UUID game, Instant createdAt, UUID... tagged) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO posts (id, author_id, game_id, created_at) VALUES (?, ?, ?, ?)",
                id, author, game, ts(createdAt));
        for (UUID t : tagged) {
            jdbc.update("INSERT INTO post_tags (post_id, tagged_user_id) VALUES (?, ?)", id, t);
        }
        return id;
    }

    // -------------------------------------------------------------------------
    // Stats
    // -------------------------------------------------------------------------

    @Test
    void statsAreComputedFromSeededData() throws Exception {
        UUID me = user();
        UUID friendA = user();
        UUID friendB = user();
        UUID gone = user();
        friends(me, friendA);
        friends(friendB, me);
        friends(me, gone);
        softDeleteUser(gone);

        UUID catan = namedGame("Catan", "Negotiation", "Economic");
        UUID azul = namedGame("Azul", "Abstract");
        UUID wishOnly = namedGame("Wish");
        entry(me, catan, true, 5, 8, null);
        entry(me, azul, true, 2, null, null);
        entry(me, wishOnly, false, 0, null, null);
        jdbc.update("UPDATE user_games SET is_wishlisted = true WHERE user_id = ? AND game_id = ?", me, wishOnly);
        jdbc.update("INSERT INTO play_logs (user_id, game_id, duration_minutes) VALUES (?, ?, 60), (?, ?, 45), (?, ?, NULL)",
                me, catan, me, catan, me, azul);

        Instant now = Instant.now();
        post(me, catan, now, friendA);
        post(friendA, azul, now, me, friendB);
        post(friendB, catan, now, me);
        post(friendA, catan, now, me); // friendA: 3 shared sessions, friendB: 2

        mvc.perform(get("/api/v1/users/{id}/stats", me).with(as(friendA)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.gamesOwned").value(2))
                .andExpect(jsonPath("$.data.sessions").value(7))
                .andExpect(jsonPath("$.data.friends").value(2))
                .andExpect(jsonPath("$.data.mostPlayedGame.gameId").value(catan.toString()))
                .andExpect(jsonPath("$.data.mostPlayedGame.title").value("Catan"))
                .andExpect(jsonPath("$.data.mostPlayedGame.playCount").value(5))
                .andExpect(jsonPath("$.data.favoriteCategory").value("Economic"))
                .andExpect(jsonPath("$.data.mostPlayedWith.userId").value(friendA.toString()))
                .andExpect(jsonPath("$.data.mostPlayedWith.sharedSessions").value(3))
                .andExpect(jsonPath("$.data.totalPlayMinutes").value(105));
    }

    @Test
    void statsOfANewUserAreEmpty() throws Exception {
        UUID me = user();
        mvc.perform(get("/api/v1/users/{id}/stats", me).with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.gamesOwned").value(0))
                .andExpect(jsonPath("$.data.sessions").value(0))
                .andExpect(jsonPath("$.data.friends").value(0))
                .andExpect(jsonPath("$.data.mostPlayedGame").isEmpty())
                .andExpect(jsonPath("$.data.favoriteCategory").isEmpty())
                .andExpect(jsonPath("$.data.mostPlayedWith").isEmpty())
                .andExpect(jsonPath("$.data.totalPlayMinutes").value(0));
    }

    @Test
    void mostPlayedWithSkipsUsersBlockedWithTheViewer() throws Exception {
        UUID me = user();
        UUID buddy = user();
        UUID viewer = user();
        post(me, game(), Instant.now(), buddy);
        block(buddy, viewer);

        mvc.perform(get("/api/v1/users/{id}/stats", me).with(as(viewer)))
                .andExpect(jsonPath("$.data.mostPlayedWith").isEmpty());
        mvc.perform(get("/api/v1/users/{id}/stats", me).with(as(me)))
                .andExpect(jsonPath("$.data.mostPlayedWith.userId").value(buddy.toString()));
    }

    @Test
    void blockedEitherWayOrDeletedLooksLikeAMissingUser() throws Exception {
        UUID me = user();
        UUID blocker = user();
        UUID blocked = user();
        UUID deleted = user();
        block(blocker, me);
        block(me, blocked);
        softDeleteUser(deleted);

        for (UUID target : List.of(blocker, blocked, deleted, UUID.randomUUID())) {
            for (String path : List.of("/stats", "/games", "/plays")) {
                mvc.perform(get("/api/v1/users/{id}" + path, target).with(as(me)))
                        .andExpect(status().isNotFound())
                        .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));
            }
        }
    }

    @Test
    void anotherUsersCollectionAndActivityAreVisibleWithoutPrivateEvents() throws Exception {
        UUID owner = user();
        UUID viewer = user();
        UUID game = game();
        entry(owner, game, true, 1, null, null);
        UUID privateEvent = UUID.randomUUID();
        UUID publicEvent = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, location, scheduled_at, visibility, status) VALUES"
                        + " (?, ?, 'Secret night', 'My flat', now() + interval '1 day', 'INVITE_ONLY', 'OPEN'),"
                        + " (?, ?, 'Open night', 'Cafe', now() + interval '1 day', 'PUBLIC', 'OPEN')",
                privateEvent, owner, publicEvent, owner);
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, 'ACCEPTED'), (?, ?, 'ACCEPTED')",
                privateEvent, owner, publicEvent, owner);

        mvc.perform(get("/api/v1/users/{id}/games?filter=owned", owner).with(as(viewer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1));

        JsonNode activity = json(mvc.perform(get("/api/v1/users/{id}/plays", owner).with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
        List<String> titles = new ArrayList<>();
        activity.forEach(item -> {
            if ("event".equals(item.get("type").asText())) {
                titles.add(item.get("eventTitle").asText());
                assertThat(item.get("location").isNull()).isTrue();
            }
        });
        assertThat(titles).containsExactly("Open night");

        JsonNode own = json(mvc.perform(get("/api/v1/users/me/plays").with(as(owner))).andReturn()).get("data");
        assertThat(own.findValuesAsText("eventTitle")).contains("Secret night", "Open night");
    }

    // -------------------------------------------------------------------------
    // Game detail friend data
    // -------------------------------------------------------------------------

    @Test
    void gameDetailCarriesFriendRatingAndOwnersPerViewer() throws Exception {
        UUID me = user();
        UUID a = user();
        UUID b = user();
        UUID stranger = user();
        friends(me, a);
        friends(b, me);
        UUID game = game(2, 4);
        entry(a, game, true, 3, 8, "Great");
        entry(b, game, false, 1, 7, null);
        entry(stranger, game, true, 9, 1, "Bad");

        mvc.perform(get("/api/v1/games/{id}", game).with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.friendAvgRating").value(7.5))
                .andExpect(jsonPath("$.data.friendRatingCount").value(2))
                .andExpect(jsonPath("$.data.ownedByFriends.length()").value(1))
                .andExpect(jsonPath("$.data.ownedByFriends[0].id").value(a.toString()))
                .andExpect(jsonPath("$.data.ownedByFriends[0].deleted").value(false));

        // The catalog part is cached without viewer data; another viewer gets their own numbers
        assertThat(cacheManager.getCache(CacheNames.GAME_DETAIL).get(game)).isNotNull();
        mvc.perform(get("/api/v1/games/{id}", game).with(as(stranger)))
                .andExpect(jsonPath("$.data.friendAvgRating").isEmpty())
                .andExpect(jsonPath("$.data.friendRatingCount").value(0))
                .andExpect(jsonPath("$.data.ownedByFriends.length()").value(0));

        mvc.perform(get("/api/v1/games/{id}/friends", game).with(as(me)))
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].user.id").value(a.toString()))
                .andExpect(jsonPath("$.data[0].playCount").value(3))
                .andExpect(jsonPath("$.data[0].personalRating").value(8))
                .andExpect(jsonPath("$.data[0].isOwned").value(true));

        mvc.perform(get("/api/v1/games/{id}/reviews", game).with(as(me)))
                .andExpect(jsonPath("$.data.length()").value(2))
                .andExpect(jsonPath("$.data[*].user.id").value(org.hamcrest.Matchers.containsInAnyOrder(
                        a.toString(), b.toString())));
        mvc.perform(get("/api/v1/games/{id}/reviews", UUID.randomUUID()).with(as(me)))
                .andExpect(status().isNotFound());
    }

    @Test
    void sessionsArePagedByCursorAndRespectFriendsAndBlocks() throws Exception {
        UUID me = user();
        UUID friend = user();
        UUID blockedFriend = user();
        UUID stranger = user();
        friends(me, friend);
        friends(me, blockedFriend);
        block(me, blockedFriend);
        UUID game = game();
        UUID otherGame = game();
        Instant base = Instant.now().minus(1, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
        UUID p1 = post(me, game, base.plusSeconds(30));
        UUID p2 = post(friend, game, base.plusSeconds(20), me);
        UUID p3 = post(friend, game, base.plusSeconds(20));
        post(stranger, game, base.plusSeconds(25));
        post(blockedFriend, game, base.plusSeconds(26));
        post(friend, otherGame, base.plusSeconds(27));
        UUID deletedPost = post(me, game, base.plusSeconds(28));
        jdbc.update("UPDATE posts SET deleted_at = now() WHERE id = ?", deletedPost);

        JsonNode page1 = json(mvc.perform(get("/api/v1/games/{id}/sessions?limit=2", game).with(as(me)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(page1.get("items")).hasSize(2);
        assertThat(page1.get("hasMore").asBoolean()).isTrue();
        assertThat(page1.get("items").get(0).get("id").asText()).isEqualTo(p1.toString());
        String cursor = page1.get("nextCursor").asText();

        JsonNode page2 = json(mvc.perform(get("/api/v1/games/{id}/sessions", game).param("limit", "2")
                        .param("cursor", cursor).with(as(me)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(page2.get("hasMore").asBoolean()).isFalse();
        assertThat(page2.get("nextCursor").isNull()).isTrue();

        List<String> all = new ArrayList<>();
        page1.get("items").forEach(i -> all.add(i.get("id").asText()));
        page2.get("items").forEach(i -> all.add(i.get("id").asText()));
        assertThat(all).containsExactlyInAnyOrder(p1.toString(), p2.toString(), p3.toString());
        assertThat(all).doesNotHaveDuplicates();

        mvc.perform(get("/api/v1/games/{id}/sessions", game).param("cursor", "not-a-cursor").with(as(me)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_CURSOR"));
        // A plain timestamp cursor returns strictly older posts
        mvc.perform(get("/api/v1/games/{id}/sessions", game).param("cursor", base.plusSeconds(30).toString())
                        .with(as(me)))
                .andExpect(jsonPath("$.data.items.length()").value(2));
    }

    @Test
    void otherUsersCollectionsHideNotesAndShowRatingsToFriendsOnly() throws Exception {
        UUID owner = user();
        UUID friend = user();
        UUID stranger = user();
        friends(owner, friend);
        UUID game = game();
        entry(owner, game, true, 2, 7, "lent to Sam, missing a card");

        JsonNode asStranger = json(mvc.perform(get("/api/v1/users/{id}/games", owner).with(as(stranger)))
                .andExpect(status().isOk()).andReturn()).get("data").get(0);
        assertThat(asStranger.path("notes").isMissingNode() || asStranger.get("notes").isNull()).isTrue();
        assertThat(asStranger.path("personalRating").isMissingNode() || asStranger.get("personalRating").isNull())
                .isTrue();
        assertThat(asStranger.get("playCount").asInt()).isEqualTo(2);

        JsonNode asFriend = json(mvc.perform(get("/api/v1/users/{id}/games", owner).with(as(friend)))
                .andExpect(status().isOk()).andReturn()).get("data").get(0);
        assertThat(asFriend.path("notes").isMissingNode() || asFriend.get("notes").isNull()).isTrue();
        assertThat(asFriend.get("personalRating").asInt()).isEqualTo(7);

        JsonNode asOwner = json(mvc.perform(get("/api/v1/users/{id}/games", owner).with(as(owner)))
                .andExpect(status().isOk()).andReturn()).get("data").get(0);
        assertThat(asOwner.get("notes").asText()).isEqualTo("lent to Sam, missing a card");
        assertThat(asOwner.get("personalRating").asInt()).isEqualTo(7);
        mvc.perform(get("/api/v1/users/me/games").with(as(owner)))
                .andExpect(jsonPath("$.data[0].notes").value("lent to Sam, missing a card"));
    }

    private String activityLocation(UUID owner, UUID viewer, UUID eventId) throws Exception {
        JsonNode activity = json(mvc.perform(get("/api/v1/users/{id}/plays", owner).with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
        for (JsonNode item : activity) {
            if ("event".equals(item.get("type").asText()) && eventId.toString().equals(item.get("eventId").asText())) {
                JsonNode location = item.get("location");
                return location == null || location.isNull() ? null : location.asText();
            }
        }
        throw new AssertionError("event " + eventId + " not in activity");
    }

    @Test
    void activityShowsTheFullAddressOfAPublicEventOnlyToItsHostAndAttendees() throws Exception {
        UUID host = user();
        UUID attendee = user();
        UUID otherAttendee = user();
        UUID stranger = user();
        UUID invited = user();
        UUID event = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, location, location_display, scheduled_at, visibility, status)"
                + " VALUES (?, ?, 'Open night', '12 Main St, flat 3', 'Downtown', now() + interval '1 day', 'PUBLIC', 'OPEN')",
                event, host);
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, 'ACCEPTED'),"
                        + " (?, ?, 'ACCEPTED'), (?, ?, 'ACCEPTED'), (?, ?, 'INVITED')",
                event, host, event, attendee, event, otherAttendee, event, invited);

        assertThat(activityLocation(attendee, attendee, event)).isEqualTo("12 Main St, flat 3");
        assertThat(activityLocation(attendee, host, event)).isEqualTo("12 Main St, flat 3");
        assertThat(activityLocation(attendee, otherAttendee, event)).isEqualTo("12 Main St, flat 3");
        assertThat(activityLocation(attendee, stranger, event)).isEqualTo("Downtown");
        assertThat(activityLocation(attendee, invited, event)).isEqualTo("Downtown");
    }
}
