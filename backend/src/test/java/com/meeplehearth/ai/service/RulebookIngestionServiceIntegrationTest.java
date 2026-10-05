package com.meeplehearth.ai.service;

import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import com.meeplehearth.support.ai.FakeOpenAi;
import com.meeplehearth.support.ai.TestPdfs;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.http.AbortableInputStream;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.ByteArrayInputStream;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** The ingestion pipeline (download → PDFBox → chunk → embed → atomic swap) against real Postgres + Redis. */
class RulebookIngestionServiceIntegrationTest extends AiGameIntegrationTestBase {

    @Autowired private RulebookIngestionService ingestionService;
    @Autowired private RulebookChunkWriter chunkWriter;
    @Autowired private ApplicationEventPublisher eventPublisher;

    private String pdfUrl(UUID rulebookId) {
        return "https://cdn.1j1ju.com/" + rulebookId + ".pdf";
    }

    private void awaitHowToPlay(UUID gameId) {
        await().atMost(Duration.ofSeconds(30)).until(() ->
                jdbc.queryForObject("SELECT COUNT(*) FROM game_how_to_play WHERE game_id = ?", Integer.class, gameId) == 1);
    }

    @Test
    void successfulIngestionReplacesOldChunksAndApproves() throws Exception {
        UUID gameId = game("Swap Game").insert();
        insertChunk(gameId, 0, "OLD chunk from a previous rulebook", FakeOpenAi.axis(7));
        UUID rulebook = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        when(pdfDownloader.download(pdfUrl(rulebook))).thenReturn(TestPdfs.withText("Fresh   rules\n\n\n\nabout trading"));

        ingestionService.ingest(rulebook);

        assertThat(rulebookStatus(rulebook)).isEqualTo("approved");
        List<String> texts = jdbc.queryForList("SELECT chunk_text FROM game_rules WHERE game_id = ?", String.class, gameId);
        assertThat(texts).hasSize(1);
        assertThat(texts.get(0)).isEqualTo("Fresh rules about trading");
        assertThat(OPENAI.embeddingInputs()).containsExactly("Fresh rules about trading");
        assertThat(redis.hasKey("lock:rulebook-ingest:" + rulebook)).isFalse();
        awaitHowToPlay(gameId);
    }

    @Test
    void rulebooksThatAreNotIngestingOrMissingAreSkipped() throws Exception {
        UUID gameId = game("Skip Game").insert();
        UUID approved = insertRulebook(gameId, "onj", "approved", Instant.now());

        ingestionService.ingest(approved);
        ingestionService.ingest(UUID.randomUUID());

        assertThat(rulebookStatus(approved)).isEqualTo("approved");
        verify(pdfDownloader, never()).download(anyString());
    }

    @Test
    void duplicateIngestionWhileLockedIsSkipped() throws Exception {
        UUID gameId = game("Locked Ingest").insert();
        UUID rulebook = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        redis.opsForValue().set("lock:rulebook-ingest:" + rulebook, "1");

        ingestionService.ingest(rulebook);

        assertThat(rulebookStatus(rulebook)).isEqualTo("ingesting");
        assertThat(redis.hasKey("lock:rulebook-ingest:" + rulebook)).as("another worker's lock is kept").isTrue();
        verify(pdfDownloader, never()).download(anyString());
    }

    @Test
    void rulebookWithoutSourceFails() {
        UUID gameId = game("No Source").insert();
        UUID rulebook = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        jdbc.update("UPDATE game_rulebooks SET pdf_url = NULL WHERE id = ?", rulebook);

        ingestionService.ingest(rulebook);

        assertThat(rulebookStatus(rulebook)).isEqualTo("failed");
    }

    @Test
    void pdfWithoutTextFails() throws Exception {
        UUID gameId = game("Blank Pdf").insert();
        UUID rulebook = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        when(pdfDownloader.download(pdfUrl(rulebook))).thenReturn(TestPdfs.blank());

        ingestionService.ingest(rulebook);

        assertThat(rulebookStatus(rulebook)).isEqualTo("failed");
        assertThat(OPENAI.embeddingInputs()).isEmpty();
    }

    @Test
    void downloadOrParseErrorsFail() throws Exception {
        UUID gameId = game("Broken Download").insert();
        UUID ioError = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        when(pdfDownloader.download(pdfUrl(ioError))).thenThrow(new com.meeplehearth.ai.client.SafePdfDownloader.TransientDownloadException("connection reset"));
        ingestionService.ingest(ioError);
        assertThat(rulebookStatus(ioError)).isEqualTo("failed");

        UUID garbage = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        when(pdfDownloader.download(pdfUrl(garbage))).thenReturn("%PDF-1.4 but truncated".getBytes());
        ingestionService.ingest(garbage);
        assertThat(rulebookStatus(garbage)).isEqualTo("failed");
    }

    @Test
    void embeddingFailureFailsAndKeepsPreviousChunks() throws Exception {
        UUID gameId = game("Embed Down").insert();
        insertChunk(gameId, 0, "Previous good chunk", FakeOpenAi.axis(8));
        UUID rulebook = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        when(pdfDownloader.download(pdfUrl(rulebook))).thenReturn(TestPdfs.withText("new rules"));
        OPENAI.failEmbeddings(500);

        ingestionService.ingest(rulebook);

        assertThat(rulebookStatus(rulebook)).isEqualTo("failed");
        assertThat(jdbc.queryForList("SELECT chunk_text FROM game_rules WHERE game_id = ?", String.class, gameId))
                .containsExactly("Previous good chunk");
    }

    @Test
    void uploadedRulebooksAreReadFromR2AndOversizedObjectsRejected() {
        UUID uploader = createUser();
        UUID gameId = game("R2 Game").insert();
        UUID ok = insertUserRulebook(gameId, uploader, "ingesting", null);
        r2Serves(TestPdfs.withText("stored rules"));
        ingestionService.ingest(ok);
        assertThat(rulebookStatus(ok)).isEqualTo("approved");
        awaitHowToPlay(gameId);

        UUID huge = insertUserRulebook(gameId, uploader, "ingesting", null);
        when(s3Client.getObject(any(GetObjectRequest.class))).thenAnswer(inv -> new ResponseInputStream<>(
                GetObjectResponse.builder().contentLength(60L * 1024 * 1024).build(),
                AbortableInputStream.create(new ByteArrayInputStream(new byte[16]))));
        ingestionService.ingest(huge);
        assertThat(rulebookStatus(huge)).isEqualTo("failed");
    }

    @Test
    void ingestionEventPublishedOutsideTransactionRunsAsync() throws Exception {
        UUID gameId = game("Event Game").insert();
        UUID rulebook = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        when(pdfDownloader.download(pdfUrl(rulebook))).thenReturn(TestPdfs.withText("event driven rules"));

        eventPublisher.publishEvent(new RulebookIngestionRequestedEvent(rulebook));

        await().atMost(Duration.ofSeconds(30)).until(() -> "approved".equals(rulebookStatus(rulebook)));
        awaitHowToPlay(gameId);
    }

    @Test
    void chunkingUses375WordWindowsWith50WordOverlap() {
        assertThat(ingestionService.chunk("one")).containsExactly("one");

        List<String> chunks = ingestionService.chunk(TestPdfs.words("w", 375));
        assertThat(chunks).hasSize(1);

        chunks = ingestionService.chunk(TestPdfs.words("w", 1000));
        assertThat(chunks).hasSize(3);
        assertThat(chunks.get(0).split(" ")).hasSize(375).startsWith("w0").endsWith("w374");
        assertThat(chunks.get(1).split(" ")).hasSize(375).startsWith("w325").endsWith("w699");
        assertThat(chunks.get(2).split(" ")).hasSize(350).startsWith("w650").endsWith("w999");
    }

    @Test
    void chunkWriterOnlyActsOnIngestingRulebooks() {
        UUID gameId = game("Writer Game").insert();
        UUID rejected = insertRulebook(gameId, "onj", "rejected", Instant.now());
        insertChunk(gameId, 0, "keep me", FakeOpenAi.axis(9));

        assertThat(chunkWriter.replaceChunks(rejected, List.of(
                new RulebookChunkWriter.EmbeddedChunk("new", 0, 1, EmbeddingService.toVectorString(FakeOpenAi.axis(1))))))
                .isFalse();
        assertThat(chunkWriter.replaceChunks(UUID.randomUUID(), List.of())).isFalse();
        assertThat(jdbc.queryForList("SELECT chunk_text FROM game_rules WHERE game_id = ?", String.class, gameId))
                .containsExactly("keep me");

        chunkWriter.markFailed(rejected);
        chunkWriter.markFailed(UUID.randomUUID());
        assertThat(rulebookStatus(rejected)).isEqualTo("rejected");

        UUID ingesting = insertRulebook(gameId, "onj", "ingesting", Instant.now());
        assertThat(chunkWriter.replaceChunks(ingesting, List.of(
                new RulebookChunkWriter.EmbeddedChunk("a", 0, 1, EmbeddingService.toVectorString(FakeOpenAi.axis(1))),
                new RulebookChunkWriter.EmbeddedChunk("b", 1, 1, EmbeddingService.toVectorString(FakeOpenAi.axis(2))))))
                .isTrue();
        assertThat(rulebookStatus(ingesting)).isEqualTo("approved");
        assertThat(jdbc.queryForList("SELECT chunk_text FROM game_rules WHERE game_id = ? ORDER BY chunk_index",
                String.class, gameId)).containsExactly("a", "b");
    }

    @Test
    void vectorLiteralFormat() {
        assertThat(EmbeddingService.toVectorString(new float[]{0.5f, -1f, 2f})).isEqualTo("[0.5,-1.0,2.0]");
        assertThat(EmbeddingService.toVectorString(new float[0])).isEqualTo("[]");
    }
}
