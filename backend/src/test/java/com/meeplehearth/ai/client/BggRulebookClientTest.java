package com.meeplehearth.ai.client;

import com.meeplehearth.support.ai.Fixtures;
import okhttp3.mockwebserver.Dispatcher;
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
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Parsing / candidate selection / download-link resolution of the BGG files client, with both
 * hardcoded hosts (api.geekdo.com, boardgamegeek.com) redirected to a MockWebServer that
 * serves captured payloads.
 */
class BggRulebookClientTest {

    private MockWebServer server;
    private BggRulebookClient client;
    /** path prefix → response; matched in insertion order is irrelevant (prefixes are distinct). */
    private final Map<String, MockResponse> routes = new ConcurrentHashMap<>();

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.setDispatcher(new Dispatcher() {
            @Override
            public MockResponse dispatch(RecordedRequest request) {
                String path = request.getPath();
                return routes.entrySet().stream()
                        .filter(e -> path.startsWith(e.getKey()))
                        .max(Map.Entry.comparingByKey((a, b) -> Integer.compare(a.length(), b.length())))
                        .map(Map.Entry::getValue)
                        .orElse(new MockResponse().setResponseCode(404));
            }
        });
        server.start();
        client = new BggRulebookClient(new RulebookUrlValidator());
        RestClient mockServer = RestClient.builder().baseUrl("http://localhost:" + server.getPort()).build();
        ReflectionTestUtils.setField(client, "bggApiClient", mockServer);
        ReflectionTestUtils.setField(client, "bggWebClient", mockServer);
    }

    @AfterEach
    void tearDown() throws IOException {
        server.shutdown();
    }

    private static MockResponse body(String body) {
        return new MockResponse().setBody(body);
    }

    private static BggRulebookClient.BggFileEntry entry(String filename, String href) {
        return new BggRulebookClient.BggFileEntry("1", "2", filename, "Rulebook", "10", "English", "2184", href, null);
    }

    @Test
    void probeParsesFilesAndSelectsRulebookCandidates() throws Exception {
        routes.put("/api/files", body(Fixtures.read("ai/bgg-files-page1.json")));

        BggRulebookClient.BggFilesProbeResult result = client.probe(13);

        assertThat(result.reachable()).isTrue();
        assertThat(result.error()).isNull();
        assertThat(result.allFiles()).hasSize(5);
        assertThat(result.rulebookCandidates()).extracting(BggRulebookClient.BggFileEntry::filename)
                .containsExactly("Catan_Rules_5th_Ed.pdf", "Base_Manual.PDF");
        assertThat(result.totalPages()).isEqualTo(2);
        assertThat(result.totalItems()).isEqualTo(15);
        assertThat(result.allFiles().get(4).postdate()).isNull();
        assertThat(result.rawJson()).contains("\"numitems\": 15");

        RecordedRequest request = server.takeRequest();
        assertThat(request.getPath()).contains("objectid=13").contains("pageid=1").doesNotContain("languageid");
    }

    @Test
    void probeWithLanguageFilterSendsLanguageId() throws Exception {
        routes.put("/api/files", body("{\"files\":[],\"config\":{}}"));

        BggRulebookClient.BggFilesProbeResult result = client.probe(13, "2184");

        assertThat(result.reachable()).isTrue();
        assertThat(result.allFiles()).isEmpty();
        assertThat(result.totalPages()).isZero();
        assertThat(server.takeRequest().getPath()).contains("languageid=2184");
    }

    @Test
    void emptyOrInvalidResponses() {
        routes.put("/api/files", body(""));
        BggRulebookClient.BggFilesProbeResult empty = client.probe(1);
        assertThat(empty.reachable()).isFalse();
        assertThat(empty.error()).isEqualTo("Empty response from BGG");

        routes.put("/api/files", body("<html>challenge</html>"));
        BggRulebookClient.BggFilesProbeResult invalid = client.probe(1);
        assertThat(invalid.reachable()).isTrue();
        assertThat(invalid.error()).startsWith("Parse error:");
        assertThat(invalid.rawJson()).isEqualTo("<html>challenge</html>");

        routes.put("/api/files", body("{\"files\":{}}"));
        assertThat(client.probe(1).allFiles()).isEmpty();
    }

    @Test
    void httpErrorsPropagateForTheCircuitBreaker() {
        routes.put("/api/files", new MockResponse().setResponseCode(503));
        assertThatThrownBy(() -> client.probe(1)).isInstanceOf(HttpServerErrorException.class);
    }

    @Test
    void downloadLinkIsExtractedFromFilepageHtml() {
        routes.put("/filepage/317826", body(Fixtures.read("ai/bgg-filepage.html")));

        assertThat(client.tryResolveDownloadUrl(entry("Catan.pdf", "/filepage/317826/catan")))
                .isEqualTo("https://boardgamegeek.com/dl/filepage/317826/Catan_Rules_5th_Ed.pdf");
    }

    @Test
    void cdnPdfLinkOrFilepageItselfIsUsedWhenNoDlLink() {
        routes.put("/filepage/1", body("<html><a href=\"https://cf.geekdo-images.com/files/rules.pdf\">x</a></html>"));
        assertThat(client.tryResolveDownloadUrl(entry("a.pdf", "/filepage/1/a")))
                .isEqualTo("https://cf.geekdo-images.com/files/rules.pdf");

        routes.put("/filepage/2", body("<html><img src=\"https://cf.geekdo-images.com/pic.png\"></html>"));
        assertThat(client.tryResolveDownloadUrl(entry("b.pdf", "/filepage/2/b")))
                .isEqualTo("https://boardgamegeek.com/filepage/2/b");

        // Not HTML: BGG streamed the file itself
        routes.put("/filepage/3", body("%PDF-1.7 binary"));
        assertThat(client.tryResolveDownloadUrl(entry("c.pdf", "/filepage/3/c")))
                .isEqualTo("https://boardgamegeek.com/filepage/3/c");
    }

    @Test
    void resolvedLinksMustPassTheAllowlist() {
        routes.put("/filepage/4", body("<!DOCTYPE html><a href=\"http://cf.geekdo-images.com/insecure.pdf\">x</a>"));
        assertThat(client.tryResolveDownloadUrl(entry("d.pdf", "/filepage/4/d"))).isNull();
    }

    @Test
    void unsafeOrNonPdfEntriesAreNeverRequested() {
        assertThat(client.tryResolveDownloadUrl(entry("x.pdf", "https://evil.example/x.pdf"))).isNull();
        assertThat(client.tryResolveDownloadUrl(entry("x.pdf", "//evil.example/x.pdf"))).isNull();
        assertThat(client.tryResolveDownloadUrl(entry("x.pdf", null))).isNull();
        assertThat(client.tryResolveDownloadUrl(entry("x.docx", "/filepage/9/x"))).isNull();
        assertThat(client.tryResolveDownloadUrl(entry(null, "/filepage/9/x"))).isNull();
        assertThat(server.getRequestCount()).isZero();
    }

    @Test
    void emptyFilepageBodyResolvesToNull() {
        routes.put("/filepage/5", new MockResponse().setResponseCode(200));
        assertThat(client.tryResolveDownloadUrl(entry("e.pdf", "/filepage/5/e"))).isNull();
    }

    @Test
    void resolveRulebookUrlWalksPagesUntilACandidateResolves() {
        // Page 1 has no rulebook candidates; page 2 does
        routes.put("/api/files?objecttype=thing&objectid=13&sort=recent&start=0&pageid=1",
                body("{\"files\":[{\"filename\":\"photo.jpg\",\"title\":\"x\",\"href\":\"/filepage/7/p\"}],"
                        + "\"config\":{\"endpage\":2,\"numitems\":11}}"));
        routes.put("/api/files?objecttype=thing&objectid=13&sort=recent&start=0&pageid=2",
                body(Fixtures.read("ai/bgg-files-page1.json")));
        routes.put("/filepage/317826", body(Fixtures.read("ai/bgg-filepage.html")));

        assertThat(client.resolveRulebookUrl(13, 5))
                .contains("https://boardgamegeek.com/dl/filepage/317826/Catan_Rules_5th_Ed.pdf");
    }

    @Test
    void resolveRulebookUrlStopsAtLastPageOrWhenUnreachable() {
        routes.put("/api/files", body("{\"files\":[],\"config\":{\"endpage\":1}}"));
        assertThat(client.resolveRulebookUrl(13, 5)).isEmpty();
        assertThat(server.getRequestCount()).isEqualTo(1);

        routes.put("/api/files", body(""));
        assertThat(client.resolveRulebookUrl(13, 5)).isEmpty();
        assertThat(server.getRequestCount()).isEqualTo(2);

        // No page info: only maxPages bounds the walk
        routes.put("/api/files", body("{\"files\":[]}"));
        assertThat(client.resolveRulebookUrl(13, 2)).isEmpty();
        assertThat(server.getRequestCount()).isEqualTo(4);
    }

    @Test
    void errorResultFactory() {
        BggRulebookClient.BggFilesProbeResult error = BggRulebookClient.BggFilesProbeResult.error(5, "boom");
        assertThat(error.reachable()).isFalse();
        assertThat(error.error()).isEqualTo("boom");
        assertThat(error.rulebookCandidates()).isEmpty();
    }
}
