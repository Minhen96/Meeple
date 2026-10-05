package com.meeplehearth.ai.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.ai.dto.RulebookUploadResponse;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.ai.repository.GameHowToPlayRepository;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.AiRateLimiter;
import com.meeplehearth.ai.service.RulebookQueueService;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class RulebookUserControllerTest {

    private final GameRepository gameRepository = mock(GameRepository.class);
    private final GameRulebookRepository rulebookRepository = mock(GameRulebookRepository.class);
    private final RulebookQueueService queueService = mock(RulebookQueueService.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final RulebookUserController controller = new RulebookUserController(gameRepository, rulebookRepository,
            mock(RulebookAutoFetchJob.class), queueService, userRepository, mock(GameHowToPlayRepository.class),
            mock(AiRateLimiter.class));

    @Test
    void uploadResponseToleratesNullQueuePosition() throws Exception {
        UUID gameId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        Game game = new Game();
        game.setId(gameId);
        User user = new User();
        user.setId(userId);
        GameRulebook rulebook = new GameRulebook();
        rulebook.setId(UUID.randomUUID());
        rulebook.setQueuePosition(null);
        when(gameRepository.findById(gameId)).thenReturn(Optional.of(game));
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(queueService.handleUserUpload(eq(game), eq(user), any(MultipartFile.class))).thenReturn(rulebook);

        ResponseEntity<RulebookUploadResponse> response = controller.uploadRulebook(gameId,
                new MockMultipartFile("file", "r.pdf", "application/pdf", "%PDF-1.4".getBytes()),
                org.springframework.security.core.userdetails.User.withUsername(userId.toString())
                        .password("").authorities("ROLE_USER").build());

        assertThat(response.getBody()).isEqualTo(RulebookUploadResponse.pendingReview(rulebook.getId(), null));
        assertThat(new ObjectMapper().writeValueAsString(response.getBody()))
                .contains("\"status\":\"pending_review\"", "\"queuePosition\":null");
    }
}
