package com.meeplehearth.common.logging;

import com.fasterxml.jackson.core.JsonStreamContext;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class SensitiveDataMaskerFeatureTest {

    private final SensitiveDataMasker masker = new SensitiveDataMasker();

    private static JsonStreamContext field(String name) {
        JsonStreamContext context = mock(JsonStreamContext.class);
        when(context.getCurrentName()).thenReturn(name);
        return context;
    }

    @Test
    void masksSensitiveFieldsEntirely() {
        assertThat(masker.mask(field("password"), "hunter2")).isEqualTo(SensitiveDataMasker.MASK);
        assertThat(masker.mask(field("fcmToken"), "abc")).isEqualTo(SensitiveDataMasker.MASK);
        assertThat(masker.mask(field("userEmail"), "x")).isEqualTo(SensitiveDataMasker.MASK);
        assertThat(masker.mask(field("Authorization"), "Bearer x")).isEqualTo(SensitiveDataMasker.MASK);
    }

    @Test
    void masksSecretsInsideMessagesAndKeepsTheRest() {
        String message = "Login for ana@example.com with Bearer abc.def-ghi, jwt eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl "
                + "reset /auth/reset-password?token=0123abcd&x=1 refresh "
                + "a3f5c0e1d2b4a6f8e0c1d3b5a7f9e1c3d5b7a9f1e3c5d7b9a1f3e5c7d9b1a3f5 "
                + "fcm dXs8Hk2LQ0e:APA91bHq1x2y3z4a5b6c7d8e9f0g1h2i3j4k5l6m7n8 user 7f8e2c1a-1111-2222-3333-444455556666";

        Object masked = masker.mask(field("message"), message);

        assertThat(masked).isInstanceOf(String.class);
        String text = (String) masked;
        assertThat(text)
                .doesNotContain("ana@example.com")
                .doesNotContain("abc.def-ghi")
                .doesNotContain("eyJhbGciOi")
                .doesNotContain("0123abcd")
                .doesNotContain("a3f5c0e1d2b4a6f8")
                .doesNotContain("APA91b")
                .contains("Login for ****")
                .contains("Bearer ****")
                .contains("token=****")
                // UUIDs (user ids) stay readable for debugging
                .contains("7f8e2c1a-1111-2222-3333-444455556666");
    }

    @Test
    void leavesHarmlessValuesUntouched() {
        String plain = "Job 'match' finished in 120 ms";
        assertThat(masker.mask(field("message"), plain)).isSameAs(plain);
        assertThat(masker.mask(field("level"), 42)).isEqualTo(42);
        assertThat(masker.mask(null, "plain")).isEqualTo("plain");
        assertThat(SensitiveDataMasker.maskText("")).isEmpty();
        assertThat(SensitiveDataMasker.maskText(null)).isNull();
        assertThat(SensitiveDataMasker.isSensitiveField(null)).isFalse();
        assertThat(SensitiveDataMasker.isSensitiveField("logger_name")).isFalse();
    }
}
