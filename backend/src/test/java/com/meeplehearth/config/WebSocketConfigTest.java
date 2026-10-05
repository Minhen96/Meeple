package com.meeplehearth.config;

import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
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
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.User;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.StompWebSocketEndpointRegistration;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.security.Principal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Handshake cookie capture and the STOMP interceptor branches not covered elsewhere. */
class WebSocketConfigTest {

    private final JwtUtil jwtUtil = mock(JwtUtil.class);
    private final UserDetailsServiceImpl userDetailsService = mock(UserDetailsServiceImpl.class);
    private final WebSocketSessionRevoker revoker = new WebSocketSessionRevoker();
    private final AppProperties props = new AppProperties();
    private final WebSocketConfig config;
    private final WebSocketConfig.StompAuthorizationInterceptor interceptor =
            new WebSocketConfig.StompAuthorizationInterceptor(jwtUtil, userDetailsService, revoker);
    private final MessageChannel channel = mock(MessageChannel.class);

    WebSocketConfigTest() {
        props.getCors().setAllowedOrigins(List.of("http://localhost:5173"));
        config = new WebSocketConfig(props, jwtUtil, userDetailsService, revoker,
                mock(com.meeplehearth.event.repository.EventRepository.class));
    }

    // ------------------------------------------------------------------ handshake

    private HandshakeInterceptor registeredHandshakeInterceptor() {
        StompEndpointRegistry registry = mock(StompEndpointRegistry.class);
        StompWebSocketEndpointRegistration registration = mock(StompWebSocketEndpointRegistration.class);
        when(registry.addEndpoint("/ws")).thenReturn(registration);
        when(registration.setAllowedOrigins(any(String[].class))).thenReturn(registration);
        when(registration.addInterceptors(any(HandshakeInterceptor[].class))).thenReturn(registration);

        config.registerStompEndpoints(registry);

        verify(registration).setAllowedOrigins("http://localhost:5173");
        ArgumentCaptor<HandshakeInterceptor> captor = ArgumentCaptor.forClass(HandshakeInterceptor.class);
        verify(registration).addInterceptors(captor.capture());
        return captor.getValue();
    }

    @Test
    void handshakeCopiesTheAccessTokenCookieIntoSessionAttributes() throws Exception {
        HandshakeInterceptor handshake = registeredHandshakeInterceptor();
        MockHttpServletRequest servletRequest = new MockHttpServletRequest("GET", "/ws");
        servletRequest.setCookies(new Cookie("theme", "dark"), new Cookie("access_token", "jwt-value"));
        Map<String, Object> attributes = new HashMap<>();

        boolean proceed = handshake.beforeHandshake(new ServletServerHttpRequest(servletRequest),
                mock(ServerHttpResponse.class), mock(WebSocketHandler.class), attributes);

        assertThat(proceed).isTrue();
        assertThat(attributes).containsExactly(Map.entry("access_token", "jwt-value"));
        handshake.afterHandshake(new ServletServerHttpRequest(servletRequest), mock(ServerHttpResponse.class),
                mock(WebSocketHandler.class), null);
    }

    @Test
    void handshakeWithoutTheCookieStillProceedsWithoutAToken() throws Exception {
        HandshakeInterceptor handshake = registeredHandshakeInterceptor();
        Map<String, Object> attributes = new HashMap<>();

        MockHttpServletRequest noCookies = new MockHttpServletRequest("GET", "/ws");
        assertThat(handshake.beforeHandshake(new ServletServerHttpRequest(noCookies), mock(ServerHttpResponse.class),
                mock(WebSocketHandler.class), attributes)).isTrue();

        MockHttpServletRequest otherCookies = new MockHttpServletRequest("GET", "/ws");
        otherCookies.setCookies(new Cookie("refresh_token", "r"));
        assertThat(handshake.beforeHandshake(new ServletServerHttpRequest(otherCookies), mock(ServerHttpResponse.class),
                mock(WebSocketHandler.class), attributes)).isTrue();

        // Non-servlet transports carry no cookies to read
        assertThat(handshake.beforeHandshake(mock(ServerHttpRequest.class), mock(ServerHttpResponse.class),
                mock(WebSocketHandler.class), attributes)).isTrue();

        assertThat(attributes).isEmpty();
    }

    @Test
    void brokerRoutesTopicsQueuesAndUserDestinations() {
        MessageBrokerRegistry registry = mock(MessageBrokerRegistry.class);

        config.configureMessageBroker(registry);

        verify(registry).enableSimpleBroker("/topic", "/queue");
        verify(registry).setApplicationDestinationPrefixes("/app");
        verify(registry).setUserDestinationPrefix("/user");
    }

    @Test
    void inboundChannelIsGuardedByTheStompInterceptor() {
        ChannelRegistration registration = mock(ChannelRegistration.class);

        config.configureClientInboundChannel(registration);

        verify(registration).interceptors(any(WebSocketConfig.StompAuthorizationInterceptor.class));
    }

    // ------------------------------------------------------------------ STOMP interceptor

    private static Message<byte[]> frame(StompHeaderAccessor accessor) {
        accessor.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders());
    }

    private static Message<byte[]> connect(String authorization, Map<String, Object> sessionAttributes) {
        StompHeaderAccessor accessor = StompHeaderAccessor.create(StompCommand.CONNECT);
        accessor.setSessionId("s1");
        accessor.setSessionAttributes(sessionAttributes);
        if (authorization != null) {
            accessor.setNativeHeader("Authorization", authorization);
        }
        return frame(accessor);
    }

    private UUID stubValidToken(String token, boolean withExpiry) {
        UUID id = UUID.randomUUID();
        var builder = Jwts.claims().subject(id.toString()).add(JwtUtil.TOKEN_VERSION_CLAIM, 0);
        if (withExpiry) {
            builder.expiration(new java.util.Date(System.currentTimeMillis() + 60_000));
        }
        Claims claims = builder.build();
        when(jwtUtil.validateAccessToken(token)).thenReturn(claims);
        when(userDetailsService.loadUserForAccessToken(id, 0))
                .thenReturn(User.withUsername(id.toString()).password("").authorities("ROLE_USER").build());
        return id;
    }

    @Test
    void framesWithoutStompHeadersOrCommandPassUntouched() {
        Message<String> plain = MessageBuilder.withPayload("x").build();
        assertThat(interceptor.preSend(plain, channel)).isSameAs(plain);

        Message<byte[]> heartbeat = frame(StompHeaderAccessor.createForHeartbeat());
        assertThat(interceptor.preSend(heartbeat, channel)).isSameAs(heartbeat);

        StompHeaderAccessor disconnect = StompHeaderAccessor.create(StompCommand.DISCONNECT);
        Message<byte[]> disconnectFrame = frame(disconnect);
        assertThat(interceptor.preSend(disconnectFrame, channel)).isSameAs(disconnectFrame);
        verify(jwtUtil, never()).validateAccessToken(any());
    }

    @Test
    void connectFallsBackToTheHandshakeCookieToken() {
        UUID id = stubValidToken("cookie-jwt", true);
        Map<String, Object> attributes = new HashMap<>();
        attributes.put("access_token", "cookie-jwt");

        // A non-Bearer Authorization header is ignored in favour of the cookie
        Message<?> out = interceptor.preSend(connect("Basic abc", attributes), channel);

        Principal user = StompHeaderAccessor.wrap(out).getUser();
        assertThat(user).isNotNull();
        assertThat(user.getName()).isEqualTo(id.toString());
        assertThat(((UsernamePasswordAuthenticationToken) user).getAuthorities())
                .extracting(Object::toString).containsExactly("ROLE_USER");
        assertThat(attributes).containsKeys(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR,
                WebSocketSessionRevoker.AUTHENTICATED_AT_ATTR);
    }

    @Test
    void connectWithBlankTokenOrNonStringCookieIsRejected() {
        assertThatThrownBy(() -> interceptor.preSend(connect("Bearer ", new HashMap<>()), channel))
                .isInstanceOf(MessageDeliveryException.class).hasMessageContaining("Authentication required");

        Map<String, Object> attributes = new HashMap<>();
        attributes.put("access_token", 42);
        assertThatThrownBy(() -> interceptor.preSend(connect(null, attributes), channel))
                .isInstanceOf(MessageDeliveryException.class).hasMessageContaining("Authentication required");

        assertThatThrownBy(() -> interceptor.preSend(connect(null, null), channel))
                .isInstanceOf(MessageDeliveryException.class).hasMessageContaining("Authentication required");
    }

    @Test
    void connectWithoutSessionAttributesOrExpiryStillAuthenticates() {
        UUID id = stubValidToken("no-exp", false);
        Map<String, Object> attributes = new HashMap<>();

        Message<?> withoutAttributes = interceptor.preSend(connect("Bearer no-exp", null), channel);
        assertThat(StompHeaderAccessor.wrap(withoutAttributes).getUser().getName()).isEqualTo(id.toString());

        interceptor.preSend(connect("Bearer no-exp", attributes), channel);
        // Without an expiry claim nothing is recorded, so later SUBSCRIBE/SEND count as expired
        assertThat(attributes).containsOnlyKeys(WebSocketSessionRevoker.AUTHENTICATED_AT_ATTR);
    }

    @Test
    void subscribeAndSendRequireAnExpiryInTheSessionAndAValidDestination() {
        Principal principal = new UsernamePasswordAuthenticationToken(UUID.randomUUID().toString(), null, List.of());

        StompHeaderAccessor noAttributes = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        noAttributes.setSessionId("s2");
        noAttributes.setDestination("/user/queue/notifications");
        noAttributes.setUser(principal);
        assertThatThrownBy(() -> interceptor.preSend(frame(noAttributes), channel))
                .isInstanceOf(MessageDeliveryException.class).hasMessageContaining("expired");

        StompHeaderAccessor send = StompHeaderAccessor.create(StompCommand.SEND);
        send.setSessionId("s2");
        send.setUser(principal);
        Map<String, Object> attributes = new HashMap<>();
        attributes.put(WebSocketSessionRevoker.TOKEN_EXPIRES_AT_ATTR, System.currentTimeMillis() + 60_000);
        send.setSessionAttributes(attributes);
        assertThatThrownBy(() -> interceptor.preSend(frame(send), channel))
                .isInstanceOf(MessageDeliveryException.class).hasMessageContaining("Sending");

        StompHeaderAccessor sendWithoutUser = StompHeaderAccessor.create(StompCommand.SEND);
        sendWithoutUser.setDestination("/app/x");
        assertThatThrownBy(() -> interceptor.preSend(frame(sendWithoutUser), channel))
                .isInstanceOf(MessageDeliveryException.class).hasMessageContaining("Authentication required");
    }

    @Test
    void subscriptionDestinationRules() {
        assertThat(WebSocketConfig.StompAuthorizationInterceptor.isSubscriptionAllowed("/user/queue/notifications")).isTrue();
        assertThat(WebSocketConfig.StompAuthorizationInterceptor.isSubscriptionAllowed("/topic/how-to-play/abc")).isTrue();

        for (String rejected : new String[]{null, "/user/queue/", "/topic/how-to-play/", "/user/queue/../x",
                "/topic/how-to-play/../../queue/x", "/app/anything", "/queue/notifications"}) {
            assertThat(WebSocketConfig.StompAuthorizationInterceptor.isSubscriptionAllowed(rejected)).as(rejected).isFalse();
        }
    }
}
