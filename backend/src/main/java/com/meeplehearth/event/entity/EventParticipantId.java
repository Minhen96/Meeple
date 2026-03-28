package com.meeplehearth.event.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class EventParticipantId implements Serializable {

    @Column(name = "event_id")
    private UUID eventId;

    @Column(name = "user_id")
    private UUID userId;

    public EventParticipantId() {}

    public EventParticipantId(UUID eventId, UUID userId) {
        this.eventId = eventId;
        this.userId = userId;
    }

    public UUID getEventId() { return eventId; }
    public UUID getUserId()  { return userId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof EventParticipantId that)) return false;
        return Objects.equals(eventId, that.eventId) && Objects.equals(userId, that.userId);
    }

    @Override
    public int hashCode() { return Objects.hash(eventId, userId); }
}
