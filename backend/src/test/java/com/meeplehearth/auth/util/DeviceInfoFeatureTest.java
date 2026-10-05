package com.meeplehearth.auth.util;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import static org.assertj.core.api.Assertions.assertThat;

class DeviceInfoFeatureTest {

    @AfterEach
    void reset() {
        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void describesCommonUserAgents() {
        assertThat(DeviceInfo.describe("Mozilla/5.0 (Windows NT 10.0; Win64) AppleWebKit Chrome/129.0 Safari/537.36 Edg/129.0"))
                .isEqualTo("Edge on Windows");
        assertThat(DeviceInfo.describe("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0; rv:131.0) Gecko Firefox/131.0"))
                .isEqualTo("Firefox on macOS");
        assertThat(DeviceInfo.describe("Mozilla/5.0 (Linux; Android 15) Chrome/129.0 Mobile Safari/537.36"))
                .isEqualTo("Chrome on Android");
        assertThat(DeviceInfo.describe("Mozilla/5.0 (X11; Linux x86_64) OPR/110 Chrome/124 Safari/537.36"))
                .isEqualTo("Opera on Linux");
        assertThat(DeviceInfo.describe("Mozilla/5.0 (X11; CrOS x86_64) Chrome/129.0 Safari/537.36"))
                .isEqualTo("Chrome on ChromeOS");
        assertThat(DeviceInfo.describe("Dart/3.5 (dart:io)")).isEqualTo("Meeple app");
        assertThat(DeviceInfo.describe("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)")).isEqualTo("iOS");
        assertThat(DeviceInfo.describe("curl/8.0")).isEqualTo(DeviceInfo.UNKNOWN);
        assertThat(DeviceInfo.describe(null)).isEqualTo(DeviceInfo.UNKNOWN);
        assertThat(DeviceInfo.describe("  ")).isEqualTo(DeviceInfo.UNKNOWN);
    }

    @Test
    void declaredDeviceHeaderWinsAfterSanitising() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("User-Agent", "Dart/3.5");
        request.addHeader(DeviceInfo.DEVICE_HEADER, "Pixel 8 <b>\u0007 · Android 15");
        assertThat(DeviceInfo.from(request)).isEqualTo("Pixel 8 b · Android 15");

        MockHttpServletRequest longHeader = new MockHttpServletRequest();
        longHeader.addHeader(DeviceInfo.DEVICE_HEADER, "x".repeat(300));
        assertThat(DeviceInfo.from(longHeader)).hasSize(DeviceInfo.MAX_LENGTH);

        MockHttpServletRequest blank = new MockHttpServletRequest();
        blank.addHeader(DeviceInfo.DEVICE_HEADER, "<>");
        blank.addHeader("User-Agent", "Mozilla/5.0 (Macintosh) Version/17 Safari/605.1");
        assertThat(DeviceInfo.from(blank)).isEqualTo("Safari on macOS");
    }

    @Test
    void readsTheCurrentRequest() {
        assertThat(DeviceInfo.fromCurrentRequest()).isNull();
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("User-Agent", "Mozilla/5.0 (Linux; Android 14) Firefox/130.0");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
        assertThat(DeviceInfo.fromCurrentRequest()).isEqualTo("Firefox on Android");
    }
}
