package com.meeplehearth.user;

import com.meeplehearth.common.event.UserHardDeletedEvent;
import com.meeplehearth.user.job.AccountHardDeleteJob;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** The daily hard-delete job removes accounts 30 days after deletion, and their R2 objects. */
@RecordApplicationEvents
class AccountHardDeleteJobFeatureTest extends AccountFeatureTestBase {

    @Autowired AccountHardDeleteJob job;
    @Autowired ApplicationEvents events;

    @Test
    void removesOnlyAccountsPastTheGracePeriod() {
        UUID expired = user();
        UUID inGrace = user();
        UUID active = user();
        jdbc.update("UPDATE users SET deleted_at = ? WHERE id = ?", ts(Instant.now().minus(Duration.ofDays(31))), expired);
        jdbc.update("UPDATE users SET deleted_at = ? WHERE id = ?", ts(Instant.now().minus(Duration.ofDays(10))), inGrace);
        UUID game = game();
        jdbc.update("INSERT INTO user_games (user_id, game_id, is_owned) VALUES (?, ?, true)", expired, game);

        String avatarKey = "avatars/" + expired + "/a.webp";
        when(s3Client.listObjectsV2(any(ListObjectsV2Request.class))).thenAnswer(inv -> {
            ListObjectsV2Request request = inv.getArgument(0);
            boolean avatars = request.prefix().equals("avatars/" + expired + "/");
            return ListObjectsV2Response.builder()
                    .contents(avatars ? java.util.List.of(S3Object.builder().key(avatarKey).build()) : java.util.List.of())
                    .isTruncated(false)
                    .build();
        });

        job.run();

        assertThat(count("SELECT count(*) FROM users WHERE id = ?", expired)).isZero();
        assertThat(count("SELECT count(*) FROM user_games WHERE user_id = ?", expired)).isZero();
        assertThat(count("SELECT count(*) FROM users WHERE id = ?", inGrace)).isEqualTo(1);
        assertThat(count("SELECT count(*) FROM users WHERE id = ?", active)).isEqualTo(1);
        assertThat(events.stream(UserHardDeletedEvent.class)).containsExactly(new UserHardDeletedEvent(expired));
        verify(s3Client).deleteObjects(argThat((DeleteObjectsRequest r) ->
                r.delete().objects().size() == 1 && r.delete().objects().get(0).key().equals(avatarKey)));
        verify(s3Client, atLeastOnce()).listObjectsV2(argThat((ListObjectsV2Request r) ->
                r.prefix().equals("uploads/" + expired + "/")));
        verify(s3Client, never()).listObjectsV2(argThat((ListObjectsV2Request r) ->
                r.prefix().contains(inGrace.toString())));
    }

    @Test
    void storageFailureDoesNotStopTheJob() {
        UUID expired = user();
        jdbc.update("UPDATE users SET deleted_at = ? WHERE id = ?", ts(Instant.now().minus(Duration.ofDays(40))), expired);
        when(s3Client.listObjectsV2(any(ListObjectsV2Request.class))).thenThrow(new IllegalStateException("R2 down"));

        assertThat(job.purgeExpiredAccounts()).isGreaterThanOrEqualTo(1);
        assertThat(count("SELECT count(*) FROM users WHERE id = ?", expired)).isZero();
    }
}
