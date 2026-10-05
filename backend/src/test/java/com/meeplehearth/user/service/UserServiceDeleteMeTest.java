package com.meeplehearth.user.service;

import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.common.event.UserSoftDeletedEvent;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceDeleteMeTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private RefreshTokenRepository refreshTokenRepository;
    @Mock
    private FriendRequestRepository friendRequestRepository;
    @Mock
    private ApplicationEventPublisher eventPublisher;
    @InjectMocks
    private UserService userService;

    @Test
    void deleteMeSoftDeletesRevokesSessionsAndPublishesUserSoftDeleted() {
        UUID userId = UUID.randomUUID();
        User user = new User();
        user.setId(userId);
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));

        userService.deleteMe(userId);

        assertThat(user.getDeletedAt()).isNotNull();
        InOrder order = inOrder(userRepository, refreshTokenRepository, eventPublisher);
        order.verify(userRepository).save(user);
        order.verify(refreshTokenRepository).deleteByUserId(userId);
        order.verify(eventPublisher).publishEvent(new UserSessionsRevokedEvent(userId));
        order.verify(eventPublisher).publishEvent(new UserSoftDeletedEvent(userId));
    }
}
