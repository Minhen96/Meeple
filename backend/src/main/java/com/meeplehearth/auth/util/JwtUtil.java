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
import java.util.Date;
import java.util.HexFormat;
import java.util.UUID;

@Component
public class JwtUtil {

    public static final String TOKEN_VERSION_CLAIM = "tv";

    private static final String ALGORITHM = "HmacSHA256";
    private static final int REFRESH_TOKEN_BYTES = 64;
    private static final int MIN_KEY_BYTES = 32; // 256 bits

    private final AppProperties appProperties;
    private final SecretKey signingKey;
    private final SecureRandom secureRandom = new SecureRandom();

    public JwtUtil(AppProperties appProperties) {
        this.appProperties = appProperties;
        this.signingKey = buildSigningKey(appProperties.getJwt().getSecret());
    }

    /**
     * Fails fast at startup when the configured secret is missing or too short for HS256.
     * A short secret is never padded: padding with zero bytes would make the key guessable.
     */
    static SecretKey buildSigningKey(String secret) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("app.jwt.secret (JWT_SECRET) must be configured");
        }
        byte[] secretBytes = secret.getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < MIN_KEY_BYTES) {
            throw new IllegalStateException(
                    "app.jwt.secret (JWT_SECRET) must be at least " + MIN_KEY_BYTES + " bytes long");
        }
        return new SecretKeySpec(secretBytes, ALGORITHM);
    }

    public String generateAccessToken(UUID userId, int tokenVersion) {
        long nowMs = System.currentTimeMillis();
        long expiryMs = appProperties.getJwt().getAccessTokenExpiryMs();

        return Jwts.builder()
                .subject(userId.toString())
                .claim("type", "access")
                .claim(TOKEN_VERSION_CLAIM, tokenVersion)
                .issuedAt(new Date(nowMs))
                .expiration(new Date(nowMs + expiryMs))
                .signWith(signingKey)
                .compact();
    }

    public String generateRefreshToken() {
        byte[] bytes = new byte[REFRESH_TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    public Claims validateAccessToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(signingKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            if (!"access".equals(claims.get("type", String.class))) {
                throw ApiException.unauthorized("Invalid or expired access token");
            }
            return claims;
        } catch (JwtException | IllegalArgumentException e) {
            throw ApiException.unauthorized("Invalid or expired access token");
        }
    }

    public UUID getUserIdFromToken(String token) {
        Claims claims = validateAccessToken(token);
        return UUID.fromString(claims.getSubject());
    }

    /** Token version embedded in the access token; tokens issued before versioning count as 0. */
    public static int getTokenVersion(Claims claims) {
        Object raw = claims.get(TOKEN_VERSION_CLAIM);
        return raw instanceof Number n ? n.intValue() : 0;
    }
}
