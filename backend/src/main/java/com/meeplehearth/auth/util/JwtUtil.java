package com.meeplehearth.auth.util;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Date;
import java.util.HexFormat;
import java.util.UUID;

@Component
public class JwtUtil {

    private static final String ALGORITHM = "HmacSHA256";
    private static final int REFRESH_TOKEN_BYTES = 64;
    private static final int MIN_KEY_BYTES = 32; // 256 bits

    private final AppProperties appProperties;
    private final SecureRandom secureRandom = new SecureRandom();

    public JwtUtil(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    private SecretKey getSigningKey() {
        byte[] secretBytes = appProperties.getJwt().getSecret().getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < MIN_KEY_BYTES) {
            secretBytes = Arrays.copyOf(secretBytes, MIN_KEY_BYTES);
        }
        return new SecretKeySpec(secretBytes, ALGORITHM);
    }

    public String generateAccessToken(UUID userId) {
        long nowMs = System.currentTimeMillis();
        long expiryMs = appProperties.getJwt().getAccessTokenExpiryMs();

        return Jwts.builder()
                .subject(userId.toString())
                .claim("type", "access")
                .issuedAt(new Date(nowMs))
                .expiration(new Date(nowMs + expiryMs))
                .signWith(getSigningKey())
                .compact();
    }

    public String generateRefreshToken() {
        byte[] bytes = new byte[REFRESH_TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    public Claims validateAccessToken(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(getSigningKey())
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (JwtException | IllegalArgumentException e) {
            throw ApiException.unauthorized("Invalid or expired access token");
        }
    }

    public UUID getUserIdFromToken(String token) {
        Claims claims = validateAccessToken(token);
        return UUID.fromString(claims.getSubject());
    }
}
