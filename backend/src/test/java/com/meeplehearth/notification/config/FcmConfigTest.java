package com.meeplehearth.notification.config;

import com.meeplehearth.config.AppProperties;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class FcmConfigTest {

    private static final String JSON = "{\"type\":\"service_account\",\"project_id\":\"demo\"}";

    @Test
    void acceptsRawJson() {
        assertThat(new String(FcmConfig.decodeServiceAccount("  " + JSON + "\n"), StandardCharsets.UTF_8)).isEqualTo(JSON);
    }

    @Test
    void acceptsStandardUrlSafeAndWrappedBase64() {
        String standard = Base64.getEncoder().encodeToString(JSON.getBytes(StandardCharsets.UTF_8));
        String urlSafe = Base64.getUrlEncoder().encodeToString((JSON + "??>>").getBytes(StandardCharsets.UTF_8));
        String wrapped = Base64.getMimeEncoder(16, "\n".getBytes()).encodeToString(JSON.getBytes(StandardCharsets.UTF_8));

        assertThat(new String(FcmConfig.decodeServiceAccount(standard), StandardCharsets.UTF_8)).isEqualTo(JSON);
        assertThat(new String(FcmConfig.decodeServiceAccount(urlSafe), StandardCharsets.UTF_8)).isEqualTo(JSON + "??>>");
        assertThat(new String(FcmConfig.decodeServiceAccount(wrapped), StandardCharsets.UTF_8)).isEqualTo(JSON);
    }

    @Test
    void rejectsNonJsonPayloads() {
        String notJson = Base64.getEncoder().encodeToString("hello".getBytes(StandardCharsets.UTF_8));
        assertThatThrownBy(() -> FcmConfig.decodeServiceAccount(notJson)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> FcmConfig.decodeServiceAccount("%%%")).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void blankOrInvalidSecretDisablesPushWithoutFailingStartup() {
        AppProperties props = new AppProperties();
        FcmConfig config = new FcmConfig();

        props.getFcm().setServiceAccountJson("");
        assertThat(config.firebaseMessaging(props)).isNull();
        props.getFcm().setServiceAccountJson("   ");
        assertThat(config.firebaseMessaging(props)).isNull();
        props.getFcm().setServiceAccountJson("{\"type\":\"service_account\"}");
        assertThat(config.firebaseMessaging(props)).isNull();
        props.getFcm().setServiceAccountJson("not base64 at all!");
        assertThat(config.firebaseMessaging(props)).isNull();
    }
}
