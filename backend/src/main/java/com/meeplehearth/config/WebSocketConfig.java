package com.meeplehearth.config;

import com.meeplehearth.auth.util.JwtUtil;
import jakarta.servlet.http.Cookie;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final AppProperties appProperties;
    private final JwtUtil jwtUtil;

    public WebSocketConfig(AppProperties appProperties, JwtUtil jwtUtil) {
        this.appProperties = appProperties;
        this.jwtUtil = jwtUtil;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
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

    /**
     * Authenticate STOMP CONNECT using:
     * 1. Authorization header (mobile)
     * 2. access_token cookie extracted during handshake (web)
     */
    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor =
                        MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

                if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
                    String token = null;

                    String authHeader = accessor.getFirstNativeHeader("Authorization");
                    if (authHeader != null && authHeader.startsWith("Bearer ")) {
                        token = authHeader.substring(7);
                    }

                    if (token == null && accessor.getSessionAttributes() != null) {
                        Object cookieToken = accessor.getSessionAttributes().get("access_token");
                        if (cookieToken instanceof String s) token = s;
                    }

                    if (token != null) {
                        try {
                            String userId = jwtUtil.getUserIdFromToken(token).toString();
                            UsernamePasswordAuthenticationToken auth =
                                    new UsernamePasswordAuthenticationToken(
                                            userId, null,
                                            List.of(new SimpleGrantedAuthority("ROLE_USER")));
                            accessor.setUser(auth);
                        } catch (Exception ignored) {
                            // Invalid token — unauthenticated
                        }
                    }
                }
                return message;
            }
        });
    }
}
