package com.meeplehearth.config;

import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.event.repository.EventRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.Cookie;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketTransportRegistration;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.security.Principal;
import java.util.Arrays;
import java.util.Date;
import java.util.Map;
import java.util.UUID;
import java.util.function.BiPredicate;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    /** Per-user queue for notifications; clients subscribe to {@code /user/queue/notifications}. */
    public static final String USER_NOTIFICATION_QUEUE = "/queue/notifications";

    private static final String USER_DESTINATION_PREFIX = "/user";
    private static final String USER_QUEUE_SUBSCRIPTION_PREFIX = "/user/queue/";
    private static final String HOW_TO_PLAY_TOPIC_PREFIX = "/topic/how-to-play/";
    /** Live participant updates of one event: {@code /topic/events/{eventId}} (section 6.3). */
    static final String EVENT_TOPIC_PREFIX = "/topic/events/";
    private static final String APP_DESTINATION_PREFIX = "/app";

    private final AppProperties appProperties;
    private final JwtUtil jwtUtil;
    private final UserDetailsServiceImpl userDetailsService;
    private final WebSocketSessionRevoker sessionRevoker;
    private final EventRepository eventRepository;

    public WebSocketConfig(AppProperties appProperties, JwtUtil jwtUtil, UserDetailsServiceImpl userDetailsService,
                           WebSocketSessionRevoker sessionRevoker, EventRepository eventRepository) {
        this.appProperties = appProperties;
        this.jwtUtil = jwtUtil;
        this.userDetailsService = userDetailsService;
        this.sessionRevoker = sessionRevoker;
        this.eventRepository = eventRepository;
    }

    /** Tracks raw sessions so revoked users' sockets can be closed (see {@link WebSocketSessionRevoker}). */
    @Override
    public void configureWebSocketTransport(WebSocketTransportRegistration registration) {
        registration.addDecoratorFactory(sessionRevoker::decorate);
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic", "/queue");
        registry.setApplicationDestinationPrefixes(APP_DESTINATION_PREFIX);
        registry.setUserDestinationPrefix(USER_DESTINATION_PREFIX);
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOrigins(appProperties.getCors().getAllowedOrigins().toArray(new String[0]))
                .addInterceptors(cookieHandshakeInterceptor());
    }

    /**
     * Extract access_token cookie from the HTTP upgrade request and pass it
     * into WebSocket session attributes so the STOMP interceptor can use it.
     */
    private HandshakeInterceptor cookieHandshakeInterceptor() {
        return new HandshakeInterceptor() {
            @Override
            public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                           WebSocketHandler wsHandler, Map<String, Object> attributes) {
                if (request instanceof ServletServerHttpRequest servletRequest) {
                    Cookie[] cookies = servletRequest.getServletRequest().getCookies();
                    if (cookies != null) {
                        Arrays.stream(cookies)
                                .filter(c -> "access_token".equals(c.getName()))
                                .findFirst()
                                .ifPresent(c -> attributes.put("access_token", c.getValue()));
                    }
                }
                return true;
            }

            @Override
            public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                       WebSocketHandler wsHandler, Exception exception) {
            }
        };
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new StompAuthorizationInterceptor(jwtUtil, userDetailsService, sessionRevoker,
                eventRepository::isVisibleTo));
    }

    /**
     * Authenticates STOMP CONNECT and authorizes SUBSCRIBE / SEND.
     * <ul>
     *   <li>CONNECT must carry a valid access token (Authorization header for mobile, or the
     *       access_token cookie captured during the handshake for web); otherwise it is rejected.
     *       The session principal's name is the user's id, which routes /user destinations.
     *       The token's expiry is stored in the session attributes.</li>
     *   <li>SUBSCRIBE and SEND are rejected, and the socket closed, once the token presented on
     *       CONNECT has expired, so clients reconnect with a fresh token.</li>
     *   <li>SUBSCRIBE is allowed only to the caller's own user queues ({@code /user/queue/**}),
     *       to public game progress topics ({@code /topic/how-to-play/**}) and to
     *       {@code /topic/events/{eventId}} for events the caller can see
     *       ({@code EventRepository.isVisibleTo}).</li>
     *   <li>SEND is allowed only to application destinations ({@code /app/**}), so clients can
     *       never publish directly onto broker topics or other users' queues.</li>
     * </ul>
     */
    static class StompAuthorizationInterceptor implements ChannelInterceptor {

        private final JwtUtil jwtUtil;
        private final UserDetailsServiceImpl userDetailsService;
        private final WebSocketSessionRevoker sessionRevoker;
        /** (eventId, userId) → may this user see the event. */
        private final BiPredicate<UUID, UUID> eventVisibility;

        /** Without an event visibility check: every /topic/events subscription is refused. */
        StompAuthorizationInterceptor(JwtUtil jwtUtil, UserDetailsServiceImpl userDetailsService,
                                      WebSocketSessionRevoker sessionRevoker) {
            this(jwtUtil, userDetailsService, sessionRevoker, (eventId, userId) -> false);
        }

        StompAuthorizationInterceptor(JwtUtil jwtUtil, UserDetailsServiceImpl userDetailsService,
                                      WebSocketSessionRevoker sessionRevoker,
                                      BiPredicate<UUID, UUID> eventVisibility) {
            this.jwtUtil = jwtUtil;
            this.userDetailsService = userDetailsService;
            this.sessionRevoker = sessionRevoker;
            this.eventVisibility = eventVisibility;
        }

        @Override
        public Message<?> preSend(Message<?> message, MessageChannel channel) {
            StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
            if (accessor == null || accessor.getCommand() == null) {
                return message;
            }

            StompCommand command = accessor.getCommand();
            if (StompCommand.CONNECT.equals(command)) {
                accessor.setUser(authenticate(accessor));
            } else if (StompCommand.SUBSCRIBE.equals(command)) {
                requireUser(accessor);
                requireUnexpiredToken(accessor);
                if (!isSubscriptionAllowed(accessor.getDestination())
                        && !isEventSubscriptionAllowed(accessor.getDestination(), accessor.getUser())) {
                    throw new MessageDeliveryException("Subscription to this destination is not allowed");
                }
            } else if (StompCommand.SEND.equals(command)) {
                requireUser(accessor);
                requireUnexpiredToken(accessor);
                String destination = accessor.getDestination();
                if (destination == null || !destination.startsWith(APP_DESTINATION_PREFIX + "/")) {
                    throw new MessageDeliveryException("Sending to this destination is not allowed");
                }
            }
            return message;
        }

        private UsernamePasswordAuthenticationToken authenticate(StompHeaderAccessor accessor) {
            String token = null;
            String authHeader = accessor.getFirstNativeHeader("Authorization");
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                token = authHeader.substring(7);
            }
            if (token == null && accessor.getSessionAttributes() != null
                    && accessor.getSessionAttributes().get("access_token") instanceof String cookieToken) {
                token = cookieToken;
            }
            if (token == null || token.isBlank()) {
                throw new MessageDeliveryException("Authentication required");
            }

            try {
                // Taken before the token version is read: a revocation committed after this
                // instant may not be visible to the check below (see WebSocketSessionRevoker)
                long authenticatedAt = sessionRevoker.currentTimeMillis();
                Claims claims = jwtUtil.validateAccessToken(token);
                UserDetails userDetails = userDetailsService.loadUserForAccessToken(
                        UUID.fromString(claims.getSubject()), JwtUtil.getTokenVersion(claims));
                Map<String, Object> attributes = accessor.getSessionAttributes();
                if (attributes != null) {
                    attributes.put(WebSocketSessionRevoker.AUTHENTICATED_AT_ATTR, authenticatedAt);
                    Date expiration = claims.getExpiration();
                    if (expiration != null) {
                        attributes.put(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR, expiration.getTime());
                    }
                }
                // Principal name is the user id: convertAndSendToUser(userId, ...) routes on it
                return new UsernamePasswordAuthenticationToken(
                        userDetails.getUsername(), null, userDetails.getAuthorities());
            } catch (RuntimeException e) {
                throw new MessageDeliveryException("Invalid or expired access token");
            }
        }

        private static void requireUser(StompHeaderAccessor accessor) {
            Principal user = accessor.getUser();
            if (user == null) {
                throw new MessageDeliveryException("Authentication required");
            }
        }

        /**
         * The token presented on CONNECT must still be valid. A missing expiry is treated as
         * expired. The socket is closed as well, since an ERROR frame alone does not make
         * clients reconnect.
         */
        private void requireUnexpiredToken(StompHeaderAccessor accessor) {
            Map<String, Object> attributes = accessor.getSessionAttributes();
            Object expiresAt = attributes == null ? null : attributes.get(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR);
            if (expiresAt instanceof Long exp && sessionRevoker.currentTimeMillis() < exp) {
                return;
            }
            sessionRevoker.closeSession(accessor.getSessionId(), WebSocketSessionRevoker.TOKEN_EXPIRED);
            throw new MessageDeliveryException("Access token expired");
        }

        /**
         * {@code /topic/events/{eventId}}: only a well-formed event id, and only for a viewer who
         * can see that event (host, invited/accepted/declined participant, friend of the host for
         * FRIENDS events unless they left or were kicked, anyone for PUBLIC events; never across a
         * block). See {@code EventRepository.VISIBLE_TO_VIEWER}.
         */
        boolean isEventSubscriptionAllowed(String destination, Principal user) {
            if (destination == null || user == null || !destination.startsWith(EVENT_TOPIC_PREFIX)) {
                return false;
            }
            String id = destination.substring(EVENT_TOPIC_PREFIX.length());
            UUID eventId;
            UUID userId;
            try {
                eventId = UUID.fromString(id);
                userId = UUID.fromString(user.getName());
            } catch (IllegalArgumentException e) {
                return false;
            }
            // UUID.fromString accepts non-canonical forms ("1-1-1-1-1"); require the canonical one
            if (!eventId.toString().equalsIgnoreCase(id)) {
                return false;
            }
            try {
                return eventVisibility.test(eventId, userId);
            } catch (RuntimeException e) {
                return false;
            }
        }

        static boolean isSubscriptionAllowed(String destination) {
            if (destination == null || destination.contains("..")) {
                return false;
            }
            // "/user/queue/x" resolves to the subscriber's own session queue; any other
            // "/user/..." form (e.g. "/user/{otherId}/queue/x") is rejected outright
            if (destination.startsWith(USER_QUEUE_SUBSCRIPTION_PREFIX)) {
                return destination.length() > USER_QUEUE_SUBSCRIPTION_PREFIX.length();
            }
            if (destination.startsWith(HOW_TO_PLAY_TOPIC_PREFIX)) {
                return destination.length() > HOW_TO_PLAY_TOPIC_PREFIX.length();
            }
            return false;
        }
    }
}
