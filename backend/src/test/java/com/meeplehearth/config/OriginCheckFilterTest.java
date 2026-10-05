package com.meeplehearth.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class OriginCheckFilterTest {

    private final OriginCheckFilter filter =
            new OriginCheckFilter(List.of("https://meeple.example.com/", "http://localhost:5173"));

    private MockHttpServletResponse run(MockHttpServletRequest request, MockFilterChain chain) throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, chain);
        return response;
    }

    private static MockHttpServletRequest request(String method, String uri) {
        MockHttpServletRequest request = new MockHttpServletRequest(method, uri);
        request.setRequestURI(uri);
        return request;
    }

    @Test
    void blocksForeignOriginOnStateChangingApiRequest() throws Exception {
        MockHttpServletRequest request = request("DELETE", "/api/v1/users/me");
        request.addHeader("Origin", "https://evil.example.com");
        MockFilterChain chain = new MockFilterChain();

        MockHttpServletResponse response = run(request, chain);

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentType()).startsWith("application/json");
        assertThat(response.getContentAsString())
                .isEqualTo("{\"error\":\"Request origin is not allowed\",\"code\":\"INVALID_ORIGIN\"}");
        assertThat(chain.getRequest()).as("chain must not continue").isNull();
    }

    @Test
    void passesAllowedOriginsThrough() throws Exception {
        MockHttpServletRequest request = request("put", "/api/v1/users/me");
        request.addHeader("Origin", "HTTPS://Meeple.Example.com");
        MockFilterChain chain = new MockFilterChain();

        MockHttpServletResponse response = run(request, chain);

        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(chain.getRequest()).isSameAs(request);
    }

    @Test
    void safeMethodsAndNonApiPathsAreNotChecked() throws Exception {
        for (MockHttpServletRequest request : List.of(
                request("GET", "/api/v1/users/me"),
                request("OPTIONS", "/api/v1/users/me"),
                request("POST", "/ws/info"),
                request("POST", "/actuator/refresh"))) {
            request.addHeader("Origin", "https://evil.example.com");
            MockFilterChain chain = new MockFilterChain();

            assertThat(run(request, chain).getStatus()).as(request.getMethod() + " " + request.getRequestURI())
                    .isEqualTo(200);
            assertThat(chain.getRequest()).isSameAs(request);
        }
    }

    @Test
    void apiPrefixIsResolvedBelowTheContextPath() throws Exception {
        MockHttpServletRequest request = request("POST", "/meeple/api/v1/posts");
        request.setContextPath("/meeple");
        request.addHeader("Origin", "https://evil.example.com");

        assertThat(run(request, new MockFilterChain()).getStatus()).isEqualTo(403);

        MockHttpServletRequest outsideContext = request("POST", "/api/v1/posts");
        outsideContext.setContextPath("/meeple");
        outsideContext.addHeader("Origin", "https://evil.example.com");
        assertThat(run(outsideContext, new MockFilterChain()).getStatus()).isEqualTo(200);
    }

    @ParameterizedTest(name = "origin={0} referer={1} -> {2}")
    @CsvSource(nullValues = "NULL", value = {
            // Origin wins over Referer whenever present
            "http://localhost:5173,     https://evil.example.com/x,          true",
            "https://evil.example.com,  http://localhost:5173/x,             false",
            "'',                        http://localhost:5173/x,             false",
            // Referer fallback, compared by scheme://host[:port]
            "NULL,  http://localhost:5173/auth/login?next=/,                  true",
            "NULL,  http://LOCALHOST:5173,                                    true",
            "NULL,  https://meeple.example.com:443/page,                      false",
            "NULL,  http://localhost:5174/page,                               false",
            "NULL,  http://localhost/page,                                    false",
            "NULL,  /relative/path,                                           false",
            "NULL,  'http://bad host/with spaces',                            false",
            "NULL,  mailto:someone@example.com,                               false",
            // Neither header: not a browser cross-site request
            "NULL,  '',                                                       true",
            "NULL,  '   ',                                                    true",
            "NULL,  NULL,                                                     true"
    })
    void originAndRefererRules(String origin, String referer, boolean allowed) {
        assertThat(filter.isAllowed(origin, referer)).isEqualTo(allowed);
    }
}
