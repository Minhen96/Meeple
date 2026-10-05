package com.meeplehearth.match;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.service.EventService;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.match.dto.CreateMatchRequestDto;
import com.meeplehearth.match.dto.MatchRequestResponse;
import com.meeplehearth.match.entity.MatchRequest;
import com.meeplehearth.match.repository.MatchGroupRepository;
import com.meeplehearth.match.repository.MatchRequestRepository;
import com.meeplehearth.match.service.MatchService;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** createRequest racing the scheduler's reactivation of an older request for the same game. */
@ExtendWith(MockitoExtension.class)
class MatchServiceCreateRequestRaceTest {

    @Mock MatchRequestRepository matchRequestRepository;
    @Mock MatchGroupRepository matchGroupRepository;
    @Mock GameRepository gameRepository;
    @Mock NotificationService notificationService;
    @Mock EventService eventService;
    @Mock PlatformTransactionManager transactionManager;

    MatchService service;

    final UUID userId = UUID.randomUUID();
    final UUID gameId = UUID.randomUUID();
    Game game;
    User user;
    CreateMatchRequestDto dto;

    @BeforeEach
    void setUp() {
        when(transactionManager.getTransaction(any())).thenAnswer(inv -> new SimpleTransactionStatus());
        service = new MatchService(matchRequestRepository, matchGroupRepository, gameRepository,
                notificationService, eventService, transactionManager);

        game = new Game();
        game.setId(gameId);
        user = new User();
        user.setId(userId);
        Instant from = Instant.now().plus(1, ChronoUnit.HOURS);
        dto = new CreateMatchRequestDto(gameId, from, from.plus(3, ChronoUnit.HOURS));

        when(gameRepository.findById(gameId)).thenReturn(Optional.of(game));
        when(matchRequestRepository.lockUser(userId)).thenReturn(Optional.of(user));
    }

    private static DataIntegrityViolationException activeIndexViolation() {
        return new DataIntegrityViolationException("could not execute statement",
                new RuntimeException("ERROR: duplicate key value violates unique constraint "
                        + "\"uq_match_requests_user_game_active\""));
    }

    @Test
    void insertRacingReactivationIsRetriedAsIdempotentUpdate() {
        MatchRequest reactivated = new MatchRequest();
        reactivated.setId(UUID.randomUUID());
        reactivated.setUser(user);
        reactivated.setGame(game);

        when(matchRequestRepository.findByUserIdAndGameIdAndStatus(userId, gameId, MatchRequest.Status.ACTIVE))
                .thenReturn(Optional.empty())               // first attempt: none yet
                .thenReturn(Optional.of(reactivated));      // retry: the scheduler's row
        when(matchRequestRepository.saveAndFlush(any())).thenThrow(activeIndexViolation());
        when(matchRequestRepository.save(reactivated)).thenReturn(reactivated);

        MatchRequestResponse response = service.createRequest(userId, dto);

        assertThat(response.id()).isEqualTo(reactivated.getId());
        assertThat(reactivated.getAvailableFrom()).isEqualTo(dto.availableFrom());
        assertThat(reactivated.getAvailableTo()).isEqualTo(dto.availableTo());
        verify(transactionManager, times(1)).rollback(any());
        verify(transactionManager, times(1)).commit(any());
    }

    @Test
    void repeatedIndexConflictBecomes409NotA500() {
        when(matchRequestRepository.findByUserIdAndGameIdAndStatus(userId, gameId, MatchRequest.Status.ACTIVE))
                .thenReturn(Optional.empty());
        when(matchRequestRepository.saveAndFlush(any())).thenThrow(activeIndexViolation());

        assertThatThrownBy(() -> service.createRequest(userId, dto))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> {
                    assertThat(((ApiException) e).getStatus()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(((ApiException) e).getCode()).isEqualTo("MATCH_REQUEST_CONFLICT");
                });
    }

    @Test
    void unrelatedIntegrityViolationIsNotSwallowed() {
        when(matchRequestRepository.findByUserIdAndGameIdAndStatus(userId, gameId, MatchRequest.Status.ACTIVE))
                .thenReturn(Optional.empty());
        when(matchRequestRepository.saveAndFlush(any()))
                .thenThrow(new DataIntegrityViolationException("fk_match_requests_game"));

        assertThatThrownBy(() -> service.createRequest(userId, dto))
                .isInstanceOf(DataIntegrityViolationException.class);
        verify(matchRequestRepository, times(1)).saveAndFlush(any());
    }
}
