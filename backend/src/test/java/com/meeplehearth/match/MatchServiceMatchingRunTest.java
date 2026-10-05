package com.meeplehearth.match;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.service.EventService;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.match.dto.CreateMatchRequestDto;
import com.meeplehearth.match.entity.MatchGroup;
import com.meeplehearth.match.entity.MatchRequest;
import com.meeplehearth.match.repository.MatchGroupRepository;
import com.meeplehearth.match.repository.MatchRequestRepository;
import com.meeplehearth.match.service.MatchService;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Branches of the matching run and of createRequest that the API tests cannot force:
 * concurrent claim failures, per-group/per-expiry failure isolation, and retry edge cases.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MatchServiceMatchingRunTest {

    @Mock MatchRequestRepository matchRequestRepository;
    @Mock MatchGroupRepository matchGroupRepository;
    @Mock GameRepository gameRepository;
    @Mock NotificationService notificationService;
    @Mock EventService eventService;
    @Mock PlatformTransactionManager transactionManager;

    MatchService service;

    @BeforeEach
    void setUp() {
        when(transactionManager.getTransaction(any())).thenAnswer(inv -> new SimpleTransactionStatus());
        when(matchGroupRepository.save(any(MatchGroup.class))).thenAnswer(inv -> {
            MatchGroup g = inv.getArgument(0);
            if (g.getId() == null) {
                g.setId(UUID.randomUUID());
            }
            return g;
        });
        service = new MatchService(matchRequestRepository, matchGroupRepository, gameRepository,
                notificationService, eventService, transactionManager);
    }

    // -------------------------------------------------------------------------
    // Matching run
    // -------------------------------------------------------------------------

    @Test
    void noActiveRequestsDoesNothingAfterExpiry() {
        service.runMatchingAlgorithm();

        verify(matchRequestRepository, never()).findFriendPairsAmongActiveRequesters();
        verify(matchGroupRepository, never()).save(any());
    }

    @Test
    void lonelyRequestPerGameIsNeverMatched() {
        Game g1 = game(null);
        Game g2 = game(null);
        User a = user(1);
        User b = user(2);
        when(matchRequestRepository.findAllActive()).thenReturn(List.of(request(a, g1), request(b, g2)));
        friendPairs(a, b);

        service.runMatchingAlgorithm();

        verify(matchRequestRepository, never()).markMatchedIfActive(anyCollection());
    }

    @Test
    void groupIsSkippedAndClaimRolledBackWhenARequestChangedSinceTheSnapshot() {
        Game game = game(null);
        User a = user(1);
        User b = user(2);
        when(matchRequestRepository.findAllActive()).thenReturn(List.of(request(a, game), request(b, game)));
        friendPairs(a, b);
        when(matchRequestRepository.markMatchedIfActive(anyCollection())).thenReturn(1); // one was cancelled

        service.runMatchingAlgorithm();

        ArgumentCaptor<TransactionStatus> committed = ArgumentCaptor.forClass(TransactionStatus.class);
        verify(transactionManager).commit(committed.capture());
        assertThat(committed.getValue().isRollbackOnly()).isTrue();
        verify(matchRequestRepository, never()).findAllWithUserAndGameByIdIn(anyCollection());
        verify(matchGroupRepository, never()).save(any());
        verify(notificationService, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void failureCreatingOneGroupIsIsolatedFromOtherGames() {
        Game broken = game(null);
        Game fine = game(null);
        User a = user(1);
        User b = user(2);
        User c = user(3);
        User d = user(4);
        MatchRequest a1 = request(a, broken);
        MatchRequest b1 = request(b, broken);
        MatchRequest c1 = request(c, fine);
        MatchRequest d1 = request(d, fine);
        when(matchRequestRepository.findAllActive()).thenReturn(List.of(a1, b1, c1, d1));
        friendPairs(a, b, c, d);
        when(matchRequestRepository.markMatchedIfActive(anyCollection()))
                .thenAnswer(inv -> ((Collection<?>) inv.getArgument(0)).size());
        when(matchRequestRepository.findAllWithUserAndGameByIdIn(anyCollection())).thenAnswer(inv -> {
            Collection<?> ids = inv.getArgument(0);
            if (ids.contains(a1.getId())) {
                throw new IllegalStateException("db hiccup");
            }
            return List.of(c1, d1);
        });

        assertThatCode(() -> service.runMatchingAlgorithm()).doesNotThrowAnyException();

        verify(transactionManager).rollback(any());
        verify(notificationService).send(eq(c.getId()), eq(Notification.NotificationType.MATCH_FOUND),
                isNull(), any(), eq("MATCH_GROUP"));
        verify(notificationService).send(eq(d.getId()), eq(Notification.NotificationType.MATCH_FOUND),
                isNull(), any(), eq("MATCH_GROUP"));
        verify(notificationService, never()).send(eq(a.getId()), any(), any(), any(), any());
    }

    @Test
    void triangleOfFriendsFormsOneGroupOfThree() {
        Game game = game(3);
        User a = user(1);
        User b = user(2);
        User c = user(3);
        List<MatchRequest> requests = List.of(request(a, game), request(b, game), request(c, game));
        when(matchRequestRepository.findAllActive()).thenReturn(requests);
        when(matchRequestRepository.findFriendPairsAmongActiveRequesters()).thenReturn(List.of(
                new Object[]{a.getId(), b.getId()},
                new Object[]{b.getId(), c.getId()},
                new Object[]{c.getId(), a.getId()}));
        when(matchRequestRepository.markMatchedIfActive(anyCollection())).thenReturn(3);
        when(matchRequestRepository.findAllWithUserAndGameByIdIn(anyCollection())).thenReturn(requests);

        service.runMatchingAlgorithm();

        ArgumentCaptor<Collection<UUID>> claimed = captor();
        verify(matchRequestRepository).markMatchedIfActive(claimed.capture());
        assertThat(claimed.getValue()).hasSize(3);
        verify(notificationService, times(3)).send(any(), eq(Notification.NotificationType.MATCH_FOUND),
                isNull(), any(), eq("MATCH_GROUP"));
    }

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void blockIsHonouredWhicheverWayRoundTheRequestsAreListed(boolean higherIdFirst) {
        Game game = game(null);
        User higher = user(9);
        User lower = user(1);
        List<MatchRequest> requests = higherIdFirst
                ? List.of(request(higher, game), request(lower, game))
                : List.of(request(lower, game), request(higher, game));
        when(matchRequestRepository.findAllActive()).thenReturn(requests);
        friendPairs(higher, lower);
        when(matchRequestRepository.findBlockPairsAmongActiveRequesters())
                .thenReturn(List.<Object[]>of(new Object[]{higher.getId(), lower.getId()}));

        service.runMatchingAlgorithm();

        verify(matchRequestRepository, never()).markMatchedIfActive(anyCollection());
    }

    @Test
    void expiryFailureForOneGroupDoesNotStopOthers() {
        UUID failing = UUID.randomUUID();
        UUID expirable = UUID.randomUUID();
        UUID raced = UUID.randomUUID();
        UUID empty = UUID.randomUUID();
        when(matchGroupRepository.findExpiredGroupIds(any())).thenReturn(List.of(failing, expirable, raced, empty));
        when(matchGroupRepository.expireIfPending(eq(failing), any())).thenThrow(new IllegalStateException("boom"));
        when(matchGroupRepository.expireIfPending(eq(expirable), any())).thenReturn(1);
        when(matchGroupRepository.expireIfPending(eq(raced), any())).thenReturn(0); // accepted meanwhile
        when(matchGroupRepository.expireIfPending(eq(empty), any())).thenReturn(1);

        Game game = game(null);
        User a = user(1);
        MatchRequest newest = request(a, game);
        MatchRequest older = request(a, game); // same (user, game): only the newest is reactivated
        when(matchRequestRepository.findReactivatableForGroups(List.of(expirable))).thenReturn(List.of(newest, older));
        when(matchRequestRepository.findReactivatableForGroups(List.of(empty))).thenReturn(List.of());

        assertThatCode(() -> service.runMatchingAlgorithm()).doesNotThrowAnyException();

        verify(matchRequestRepository).reactivateIfNoActive(List.of(newest.getId()));
        verify(matchRequestRepository, never()).findReactivatableForGroups(List.of(raced));
        verify(matchRequestRepository, times(1)).reactivateIfNoActive(anyCollection());
    }

    // -------------------------------------------------------------------------
    // createRequest edge cases
    // -------------------------------------------------------------------------

    @Test
    void openEndedWindowSkipsTimeValidationAndUnknownUserIs404() {
        Game game = game(null);
        UUID userId = UUID.randomUUID();
        when(gameRepository.findById(game.getId())).thenReturn(Optional.of(game));
        when(matchRequestRepository.lockUser(userId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createRequest(userId,
                new CreateMatchRequestDto(game.getId(), Instant.now().plusSeconds(60), null)))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(e.getCode()).isEqualTo("USER_NOT_FOUND");
                });
    }

    @Test
    void unrelatedIntegrityViolationOnFirstAttemptIsNotRetried() {
        Game game = game(null);
        User u = user(1);
        when(gameRepository.findById(game.getId())).thenReturn(Optional.of(game));
        when(matchRequestRepository.lockUser(u.getId())).thenReturn(Optional.of(u));
        when(matchRequestRepository.findByUserIdAndGameIdAndStatus(u.getId(), game.getId(), MatchRequest.Status.ACTIVE))
                .thenReturn(Optional.empty());
        when(matchRequestRepository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("fk_user"));

        assertThatThrownBy(() -> service.createRequest(u.getId(), new CreateMatchRequestDto(game.getId(), null, null)))
                .isInstanceOf(DataIntegrityViolationException.class);
        verify(matchRequestRepository, times(1)).saveAndFlush(any());
    }

    @Test
    void indexViolationIsFoundInTheCauseChainEvenWithoutATopLevelMessage() {
        Game game = game(null);
        User u = user(1);
        when(gameRepository.findById(game.getId())).thenReturn(Optional.of(game));
        when(matchRequestRepository.lockUser(u.getId())).thenReturn(Optional.of(u));
        MatchRequest existing = request(u, game);
        when(matchRequestRepository.findByUserIdAndGameIdAndStatus(u.getId(), game.getId(), MatchRequest.Status.ACTIVE))
                .thenReturn(Optional.empty())
                .thenReturn(Optional.of(existing));
        when(matchRequestRepository.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException(null,
                new RuntimeException("duplicate key violates \"uq_match_requests_user_game_active\"")));
        when(matchRequestRepository.save(existing)).thenReturn(existing);

        assertThat(service.createRequest(u.getId(), new CreateMatchRequestDto(game.getId(), null, null)).id())
                .isEqualTo(existing.getId());
    }

    @Test
    void unrelatedIntegrityViolationOnTheRetryIsNotMaskedAsConflict() {
        Game game = game(null);
        User u = user(1);
        when(gameRepository.findById(game.getId())).thenReturn(Optional.of(game));
        when(matchRequestRepository.lockUser(u.getId())).thenReturn(Optional.of(u));
        when(matchRequestRepository.findByUserIdAndGameIdAndStatus(u.getId(), game.getId(), MatchRequest.Status.ACTIVE))
                .thenReturn(Optional.empty());
        when(matchRequestRepository.saveAndFlush(any()))
                .thenThrow(new DataIntegrityViolationException("x",
                        new RuntimeException("uq_match_requests_user_game_active")))
                .thenThrow(new DataIntegrityViolationException("fk_user"));

        assertThatThrownBy(() -> service.createRequest(u.getId(), new CreateMatchRequestDto(game.getId(), null, null)))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessage("fk_user");
        verify(matchRequestRepository, times(2)).saveAndFlush(any());
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private void friendPairs(User... users) {
        List<Object[]> rows = new ArrayList<>();
        for (int i = 0; i + 1 < users.length; i += 2) {
            rows.add(new Object[]{users[i].getId(), users[i + 1].getId()});
        }
        when(matchRequestRepository.findFriendPairsAmongActiveRequesters()).thenReturn(rows);
    }

    private static User user(long n) {
        User u = new User();
        u.setId(new UUID(0, n));
        return u;
    }

    private static Game game(Integer minPlayers) {
        Game g = new Game();
        g.setId(UUID.randomUUID());
        g.setNameEn("Unit Game");
        g.setMinPlayers(minPlayers);
        return g;
    }

    private static MatchRequest request(User user, Game game) {
        MatchRequest mr = new MatchRequest();
        mr.setId(UUID.randomUUID());
        mr.setUser(user);
        mr.setGame(game);
        return mr;
    }

    @SuppressWarnings("unchecked")
    private static ArgumentCaptor<Collection<UUID>> captor() {
        return ArgumentCaptor.forClass((Class<Collection<UUID>>) (Class<?>) Collection.class);
    }
}
