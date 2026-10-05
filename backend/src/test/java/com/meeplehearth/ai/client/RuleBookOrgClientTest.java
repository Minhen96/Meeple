package com.meeplehearth.ai.client;

import com.meeplehearth.support.ai.Fixtures;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestClient;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** rule-book.org search parsing with the hardcoded API host redirected to a MockWebServer. */
class RuleBookOrgClientTest {

    private MockWebServer server;
    private RuleBookOrgClient client;

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.start();
        client = new RuleBookOrgClient();
        ReflectionTestUtils.setField(client, "restClient",
                RestClient.builder().baseUrl("http://localhost:" + server.getPort()).build());
    }

    @AfterEach
    void tearDown() throws IOException {
        server.shutdown();
    }

    @Test
    void returnsFirstResultLinkAndSendsEncodedQuery() throws Exception {
        server.enqueue(new MockResponse().setBody(Fixtures.read("ai/rulebook-org-search.json")));

        assertThat(client.findPdfUrl("Catan & Friends"))
                .contains("https://cdn.1j1ju.com/medias/7a/18/fd-catan-rulebook.pdf");

        RecordedRequest request = server.takeRequest();
        assertThat(request.getRequestUrl().encodedPath()).isEqualTo("/games");
        assertThat(request.getRequestUrl().queryParameter("search")).isEqualTo("Catan & Friends");
        assertThat(request.getRequestUrl().queryParameter("language")).isEqualTo("en");
    }

    @Test
    void noUsableResultIsEmpty() {
        server.enqueue(new MockResponse().setBody("{\"results\":[]}"));
        server.enqueue(new MockResponse().setBody("{\"results\":{}}"));
        server.enqueue(new MockResponse().setBody("{\"results\":[{\"name\":\"x\",\"link\":\"\"}]}"));
        server.enqueue(new MockResponse().setBody("{\"results\":[{\"name\":\"x\"}]}"));
        server.enqueue(new MockResponse().setBody(""));
        server.enqueue(new MockResponse().setResponseCode(404));

        for (int i = 0; i < 6; i++) {
            assertThat(client.findPdfUrl("Unknown")).as("response %d", i).isEmpty();
        }
    }

    @Test
    void invalidJsonAndServerErrorsAreFailuresForTheCircuitBreaker() {
        server.enqueue(new MockResponse().setBody("<html>maintenance</html>"));
        assertThatThrownBy(() -> client.findPdfUrl("Catan"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Invalid JSON");

        server.enqueue(new MockResponse().setResponseCode(502));
        assertThatThrownBy(() -> client.findPdfUrl("Catan")).isInstanceOf(HttpServerErrorException.class);
    }
}
