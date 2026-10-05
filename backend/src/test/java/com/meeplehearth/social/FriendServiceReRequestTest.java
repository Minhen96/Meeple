package com.meeplehearth.social;

import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.social.dto.FriendRequestResponse;
import com.meeplehearth.social.entity.FriendRequest;
import com.meeplehearth.social.repository.BlockRepository;
import com.meeplehearth.social.repository.FriendRequestRepository;
import com.meeplehearth.social.service.FriendService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FriendServiceReRequestTest {

    @Mock FriendRequestRepository friendRequestRepository;
    @Mock BlockRepository blockRepository;
    @Mock UserRepository userRepository;
    @Mock NotificationService notificationService;

    @Test
    void reRequestAfterDeclineByOtherSideMakesCurrentUserTheSender() {
        FriendService service = new FriendService(friendRequestRepository, blockRepository,
                userRepository, notificationService);

        User alice = user("alice");
        User bob = user("bob");

        // Bob asked Alice earlier and Alice declined; now Alice sends a request to Bob
        FriendRequest declined = new FriendRequest();
        declined.setId(UUID.randomUUID());
        declined.setSender(bob);
        declined.setReceiver(alice);
        declined.setStatus(FriendRequest.Status.DECLINED);

        when(userRepository.findById(bob.getId())).thenReturn(Optional.of(bob));
        when(userRepository.findById(alice.getId())).thenReturn(Optional.of(alice));
        when(blockRepository.existsBlockBetween(alice.getId(), bob.getId())).thenReturn(false);
        when(friendRequestRepository.findBetween(alice.getId(), bob.getId())).thenReturn(List.of(declined));
        when(friendRequestRepository.save(any(FriendRequest.class))).thenAnswer(inv -> inv.getArgument(0));

        FriendRequestResponse response = service.sendFriendRequest(alice.getId(), bob.getId());

        assertThat(declined.getSender()).isSameAs(alice);
        assertThat(declined.getReceiver()).isSameAs(bob);
        assertThat(declined.getStatus()).isEqualTo(FriendRequest.Status.PENDING);
        assertThat(response.sender().id()).isEqualTo(alice.getId());
        assertThat(response.receiver().id()).isEqualTo(bob.getId());
        verify(notificationService).send(bob.getId(), Notification.NotificationType.FRIEND_REQUEST,
                alice.getId(), declined.getId(), "FRIEND_REQUEST");
    }

    private static User user(String username) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setUsername(username);
        u.setEmail(username + "@example.test");
        return u;
    }
}
