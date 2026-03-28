package com.meeplehearth.event.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "event_participants")
@Getter
@Setter
public class EventParticipant {

    @EmbeddedId
    private EventParticipantId id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId("eventId")
    @JoinColumn(name = "event_id")
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId("userId")
    @JoinColumn(name = "user_id")
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private RsvpStatus status = RsvpStatus.INVITED;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private Instant joinedAt = Instant.now();

    public EventParticipant() {}

    public EventParticipant(Event event, User user, RsvpStatus status) {
        this.id = new EventParticipantId(event.getId(), user.getId());
        this.event = event;
        this.user = user;
        this.status = status;
    }

    public enum RsvpStatus { INVITED, ACCEPTED, DECLINED }
}
