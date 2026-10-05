package com.meeplehearth.match;

import com.meeplehearth.event.service.EventService;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.match.entity.MatchGroup;
import com.meeplehearth.match.entity.MatchGroupMember;
import com.meeplehearth.match.entity.MatchGroupMemberId;
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
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** dismissMatch racing a concurrent createRequest on the one-ACTIVE-per-game unique index. */
@ExtendWith(MockitoExtension.class)
class MatchServiceDismissRaceTest {

    @Mock MatchRequestRepository matchRequestRepository;
    @Mock MatchGroupRepository matchGroupRepository;
    @Mock GameRepository gameRepository;
    @Mock NotificationService notificationService;
    @Mock EventService eventService;
    @Mock PlatformTransactionManager transactionManager;

    MatchService service;

    final UUID userId = UUID.randomUUID();
    final UUID groupId = UUID.randomUUID();
    MatchGroup group;
    MatchRequest matched;

    @BeforeEach
    void setUp() {
        when(transactionManager.getTransaction(any())).thenAnswer(inv -> new SimpleTransactionStatus());
        service = new MatchService(matchRequestRepository, matchGroupRepository, gameRepository,
                notificationService, eventService, transactionManager);

        User user = new User();
        user.setId(userId);
        Game game = new Game();
        game.setId(UUID.randomUUID());

        group = new MatchGroup();
        group.setId(groupId);
        group.setGame(game);
        MatchGroupMember member = new MatchGroupMember();
        member.setId(new MatchGroupMemberId(groupId, userId));
        member.setGroup(group);
        member.setUser(user);
        group.getMembers().add(member);

        matched = new MatchRequest();
        matched.setId(UUID.randomUUID());
        matched.setUser(user);
        matched.setGame(game);
        matched.setStatus(MatchRequest.Status.MATCHED);

        when(matchGroupRepository.findByIdForUpdate(groupId)).thenReturn(Optional.of(group));
    }

    private static DataIntegrityViolationException activeIndexViolation() {
        return new DataIntegrityViolationException("could not execute statement",
                new RuntimeException("ERROR: duplicate key value violates unique constraint "
                        + "\"uq_match_requests_user_game_active\""));
    }

    @Test
    void lastDismissalReactivatesThroughConflictSafeUpdate() {
        when(matchRequestRepository.findReactivatableForGroups(List.of(groupId))).thenReturn(List.of(matched));
        when(matchRequestRepository.reactivateIfNoActive(List.of(matched.getId()))).thenReturn(1);

        service.dismissMatch(userId, groupId);

        assertThat(group.getStatus()).isEqualTo(MatchGroup.Status.DISMISSED);
        verify(matchRequestRepository, times(1)).reactivateIfNoActive(List.of(matched.getId()));
        verify(transactionManager, times(2)).commit(any()); // dismissal, then reactivation
    }

    @Test
    void indexRaceDuringReactivationIsRetriedNotA500() {
        when(matchRequestRepository.findReactivatableForGroups(List.of(groupId))).thenReturn(List.of(matched));
        when(matchRequestRepository.reactivateIfNoActive(anyCollection()))
                .thenThrow(activeIndexViolation())
                .thenReturn(0); // retry sees the concurrently created ACTIVE row and skips it

        assertThatCode(() -> service.dismissMatch(userId, groupId)).doesNotThrowAnyException();

        assertThat(group.getStatus()).isEqualTo(MatchGroup.Status.DISMISSED);
        verify(matchRequestRepository, times(2)).reactivateIfNoActive(anyCollection());
    }

    @Test
    void persistentIndexConflictIsSkippedAndDismissalStillSucceeds() {
        when(matchRequestRepository.findReactivatableForGroups(List.of(groupId))).thenReturn(List.of(matched));
        when(matchRequestRepository.reactivateIfNoActive(anyCollection())).thenThrow(activeIndexViolation());

        assertThatCode(() -> service.dismissMatch(userId, groupId)).doesNotThrowAnyException();

        verify(matchRequestRepository, times(2)).reactivateIfNoActive(anyCollection());
        verify(matchGroupRepository).save(group); // the dismissal was committed first
    }

    @Test
    void unrelatedIntegrityViolationIsNotSwallowed() {
        when(matchRequestRepository.findReactivatableForGroups(List.of(groupId))).thenReturn(List.of(matched));
        when(matchRequestRepository.reactivateIfNoActive(anyCollection()))
                .thenThrow(new DataIntegrityViolationException("fk_match_requests_user"));

        assertThatThrownBy(() -> service.dismissMatch(userId, groupId))
                .isInstanceOf(DataIntegrityViolationException.class);
        verify(matchRequestRepository, times(1)).reactivateIfNoActive(anyCollection());
    }

    @Test
    void groupWithRemainingMembersIsNotReactivated() {
        User other = new User();
        other.setId(UUID.randomUUID());
        MatchGroupMember pending = new MatchGroupMember();
        pending.setId(new MatchGroupMemberId(groupId, other.getId()));
        pending.setGroup(group);
        pending.setUser(other);
        group.getMembers().add(pending);

        service.dismissMatch(userId, groupId);

        assertThat(group.getStatus()).isEqualTo(MatchGroup.Status.PENDING);
        verify(matchRequestRepository, never()).reactivateIfNoActive(anyCollection());
    }
}
