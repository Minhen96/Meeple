package com.meeplehearth.auth.util;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;

import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtUtilTest {

    private static final String LOCAL_DEFAULT_SECRET = "local-dev-secret-must-be-at-least-256-bits-long-xx";

    private static AppProperties props(String secret) {
        AppProperties props = new AppProperties();
        props.getJwt().setSecret(secret);
        props.getJwt().setAccessTokenExpiryMs(900_000);
        return props;
    }

    @Test
    void rejectsSecretShorterThan32Bytes() {
        assertThatThrownBy(() -> new JwtUtil(props("too-short-secret")))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("32 bytes");
    }

    @Test
    void rejectsMissingSecret() {
        assertThatThrownBy(() -> new JwtUtil(props(null))).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new JwtUtil(props("   "))).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void acceptsExactly32ByteSecretAndLocalDefault() {
        new JwtUtil(props("a".repeat(32)));
        assertThat(LOCAL_DEFAULT_SECRET.getBytes(StandardCharsets.UTF_8).length).isGreaterThanOrEqualTo(32);
        new JwtUtil(props(LOCAL_DEFAULT_SECRET));
    }

    @Test
    void accessTokenCarriesTokenVersion() {
        JwtUtil jwtUtil = new JwtUtil(props(LOCAL_DEFAULT_SECRET));
        UUID userId = UUID.randomUUID();

        Claims claims = jwtUtil.validateAccessToken(jwtUtil.generateAccessToken(userId, 7));

        assertThat(claims.getSubject()).isEqualTo(userId.toString());
        assertThat(JwtUtil.getTokenVersion(claims)).isEqualTo(7);
    }

    @Test
    void tokenWithoutVersionClaimCountsAsVersionZero() {
        JwtUtil jwtUtil = new JwtUtil(props(LOCAL_DEFAULT_SECRET));
        String legacy = Jwts.builder()
                .subject(UUID.randomUUID().toString())
                .claim("type", "access")
                .expiration(new Date(System.currentTimeMillis() + 60_000))
                .signWith(new SecretKeySpec(LOCAL_DEFAULT_SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"))
                .compact();

        assertThat(JwtUtil.getTokenVersion(jwtUtil.validateAccessToken(legacy))).isZero();
    }

    @Test
    void rejectsTokenSignedWithDifferentKey() {
        JwtUtil issuer = new JwtUtil(props("b".repeat(40)));
        JwtUtil verifier = new JwtUtil(props(LOCAL_DEFAULT_SECRET));

        String token = issuer.generateAccessToken(UUID.randomUUID(), 0);

        assertThatThrownBy(() -> verifier.validateAccessToken(token)).isInstanceOf(ApiException.class);
    }
}
