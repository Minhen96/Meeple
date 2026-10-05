package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.client.BggRulebookClient;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.ResultActions;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Admin AI diagnostics: provider probe over the fake OpenAI server, PDF download and BGG probes. */
class AiAdminControllerIntegrationTest extends AiGameIntegrationTestBase {

    @Autowired private AppProperties appProperties;

    private ResultActions call(UUID admin, String path) throws Exception {
        return mvc.perform(get("/api/v1/admin" + path).cookie(auth(admin)));
    }

    @Test
    void aiProbePassesWith1536DimEmbeddingsAndACompletion() throws Exception {
        UUID admin = createUser("ADMIN");
        OPENAI.onCompletion(body -> "hello");

        call(admin, "/test/ai")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ok").value(true))
                .andExpect(jsonPath("$.data.embeddingDims").value(1536))
                .andExpect(jsonPath("$.data.embeddingPass").value(true))
                .andExpect(jsonPath("$.data.completionResponse").value("hello"))
                .andExpect(jsonPath("$.data.completionPass").value(true))
                .andExpect(jsonPath("$.data.completionBaseUrl").value(OPENAI.baseUrl()))
                .andExpect(jsonPath("$.data.verdict").value("AI provider configured correctly. Safe to proceed."));
    }

    @Test
    void aiProbeReportsEachFailingCheck() throws Exception {
        UUID admin = createUser("ADMIN");
        OPENAI.failEmbeddings(401);
        OPENAI.onCompletion(body -> "   ");

        call(admin, "/test/ai")
                .andExpect(jsonPath("$.data.ok").value(false))
                .andExpect(jsonPath("$.data.embeddingPass").value(false))
                .andExpect(jsonPath("$.data.embeddingError").value(org.hamcrest.Matchers.containsString("401")))
                .andExpect(jsonPath("$.data.completionPass").value(false));

        OPENAI.reset();
        OPENAI.onEmbedding(text -> new float[3]);
        OPENAI.failCompletions(500);
        call(admin, "/test/ai")
                .andExpect(jsonPath("$.data.embeddingDims").value(3))
                .andExpect(jsonPath("$.data.embeddingPass").value(false))
                .andExpect(jsonPath("$.data.completionPass").value(false))
                .andExpect(jsonPath("$.data.completionError").exists());
    }

    @Test
    void aiProbeWithoutKeyDoesNotCallProvider() throws Exception {
        UUID admin = createUser("ADMIN");
        String key = appProperties.getAi().getCompletion().getApiKey();
        appProperties.getAi().getCompletion().setApiKey(" ");
        try {
            call(admin, "/test/ai")
                    .andExpect(jsonPath("$.data.ok").value(false))
                    .andExpect(jsonPath("$.data.error").value("AI_COMPLETION_API_KEY not set — add it to .env.local"));
        } finally {
            appProperties.getAi().getCompletion().setApiKey(key);
        }
        org.assertj.core.api.Assertions.assertThat(OPENAI.completionRequests()).isEmpty();
    }

    @Test
    void pdfDownloadProbe() throws Exception {
        UUID admin = createUser("ADMIN");
        when(pdfDownloader.download(anyString())).thenReturn(new byte[150_000]);
        call(admin, "/test/pdf-download")
                .andExpect(jsonPath("$.data.downloadable").value(true))
                .andExpect(jsonPath("$.data.sizeBytes").value(150_000))
                .andExpect(jsonPath("$.data.pass").value(true));

        when(pdfDownloader.download(anyString())).thenReturn(new byte[10]);
        call(admin, "/test/pdf-download")
                .andExpect(jsonPath("$.data.pass").value(false))
                .andExpect(jsonPath("$.data.verdict").value("Downloaded but content looks too small — check sizeBytes."));

        when(pdfDownloader.download(anyString())).thenThrow(new com.meeplehearth.ai.client.SafePdfDownloader.PdfDownloadException("blocked"));
        call(admin, "/test/pdf-download")
                .andExpect(jsonPath("$.data.downloadable").value(false))
                .andExpect(jsonPath("$.data.error").value("blocked"));
    }

    private static BggRulebookClient.BggFileEntry entry(String filename, String title) {
        return new BggRulebookClient.BggFileEntry("1", "2", filename, title, "100", "English", "2184",
                "/filepage/1/rules", "2024-01-01");
    }

    @Test
    void bggProbesAndResolve() throws Exception {
        UUID admin = createUser("ADMIN");
        var candidate = entry("rules.pdf", "Rulebook");
        var reachable = new BggRulebookClient.BggFilesProbeResult(13, true, null, List.of(candidate),
                List.of(candidate), 2, 11, "{}");
        when(bggRulebookClient.probe(13L)).thenReturn(reachable);
        when(bggRulebookClient.probe(eq(13L), eq("2184"))).thenReturn(reachable);
        when(bggRulebookClient.tryResolveDownloadUrl(any())).thenReturn("https://boardgamegeek.com/dl/1/rules.pdf");

        call(admin, "/test/bgg-rulebook/13")
                .andExpect(jsonPath("$.data.reachable").value(true))
                .andExpect(jsonPath("$.data.rulebookCandidates[0].filename").value("rules.pdf"));
        call(admin, "/test/bgg-rulebook/13/english")
                .andExpect(jsonPath("$.data.totalItems").value(11));
        call(admin, "/test/bgg-rulebook/13/resolve")
                .andExpect(jsonPath("$.data.totalRulebookCandidates").value(1))
                .andExpect(jsonPath("$.data.resolvedUrl").value("https://boardgamegeek.com/dl/1/rules.pdf"))
                .andExpect(jsonPath("$.data.note").value("Resolved. Verify manually that URL returns a PDF."));

        when(bggRulebookClient.tryResolveDownloadUrl(any())).thenReturn(null);
        call(admin, "/test/bgg-rulebook/13/resolve")
                .andExpect(jsonPath("$.data.resolvedUrl").doesNotExist())
                .andExpect(jsonPath("$.data.note").value("Could not extract download URL — BGG may require auth."));

        when(bggRulebookClient.probe(eq(14L), eq("2184"))).thenReturn(new BggRulebookClient.BggFilesProbeResult(
                14, true, null, List.of(), List.of(), 3, 25, "{}"));
        call(admin, "/test/bgg-rulebook/14/resolve")
                .andExpect(jsonPath("$.data.note").value("No rulebook candidates on first page. Total: 25 files across 3 pages."));

        when(bggRulebookClient.probe(eq(15L), eq("2184"))).thenReturn(new BggRulebookClient.BggFilesProbeResult(
                15, false, "timeout", List.of(), List.of(), 0, 0, null));
        call(admin, "/test/bgg-rulebook/15/resolve")
                .andExpect(jsonPath("$.data.reachable").value(false))
                .andExpect(jsonPath("$.data.note").value("BGG API not reachable: timeout"));
    }

    @Test
    void probesAreAdminOnly() throws Exception {
        UUID user = createUser();
        mvc.perform(get("/api/v1/admin/test/ai").cookie(auth(user))).andExpect(status().isForbidden());
    }
}
