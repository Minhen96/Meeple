package com.meeplehearth.event;

import com.meeplehearth.event.entity.EventParticipantId;
import org.junit.jupiter.api.Test;

import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** JPA identity of event participants (and existsById/deleteById in leaveEvent) relies on value equality. */
class EventParticipantIdTest {

    @Test
    void equalityIsByEventAndUser() {
        UUID event = UUID.randomUUID();
        UUID user = UUID.randomUUID();
        EventParticipantId id = new EventParticipantId(event, user);

        assertThat(id).isEqualTo(id);
        assertThat(id).isEqualTo(new EventParticipantId(event, user))
                .hasSameHashCodeAs(new EventParticipantId(event, user));
        assertThat(id).isNotEqualTo(new EventParticipantId(event, UUID.randomUUID()));
        assertThat(id).isNotEqualTo(new EventParticipantId(UUID.randomUUID(), user));
        assertThat(id).isNotEqualTo(new EventParticipantId(user, event));
        assertThat(id).isNotEqualTo(null);
        assertThat(id).isNotEqualTo("not an id");
        assertThat(new EventParticipantId()).isEqualTo(new EventParticipantId());
        assertThat(Set.of(id)).contains(new EventParticipantId(event, user));
        assertThat(id.getEventId()).isEqualTo(event);
        assertThat(id.getUserId()).isEqualTo(user);
    }
}
