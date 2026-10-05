package com.meeplehearth.support.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import okhttp3.mockwebserver.Dispatcher;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Function;

/**
 * In-process stand-in for the OpenAI-compatible completion and embedding APIs, served by
 * OkHttp's MockWebServer. The real {@code AiCompletionService} / {@code EmbeddingService} beans
 * are pointed at it via {@code app.ai.*.base-url}, so the full HTTP + JSON path is exercised
 * without ever calling a real provider.
 *
 * One JVM-wide instance: tests run sequentially, and {@link #reset()} restores the defaults
 * before every test.
 */
public final class FakeOpenAi {

    public static final int DIMENSIONS = 1536;

    private static final FakeOpenAi INSTANCE = new FakeOpenAi();
    private static final ObjectMapper JSON = new ObjectMapper();

    private final MockWebServer server = new MockWebServer();
    private volatile Function<JsonNode, String> completionResponder;
    private volatile Function<String, float[]> embeddingResponder;
    private volatile int completionStatus;
    private volatile int embeddingStatus;
    private final List<JsonNode> completionRequests = new CopyOnWriteArrayList<>();
    private final List<String> embeddingInputs = new CopyOnWriteArrayList<>();
    private final List<String> authorizationHeaders = new CopyOnWriteArrayList<>();

    private FakeOpenAi() {
        reset();
        server.setDispatcher(new Dispatcher() {
            @Override
            public MockResponse dispatch(RecordedRequest request) {
                try {
                    return handle(request);
                } catch (Exception e) {
                    return new MockResponse().setResponseCode(500).setBody("fake failure: " + e.getMessage());
                }
            }
        });
        try {
            server.start();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public static FakeOpenAi instance() {
        return INSTANCE;
    }

    public String baseUrl() {
        return "http://localhost:" + server.getPort();
    }

    /** Restores the default behaviour: every completion answers "ok", embeddings are deterministic. */
    public void reset() {
        completionResponder = body -> "ok";
        embeddingResponder = FakeOpenAi::hashVector;
        completionStatus = 200;
        embeddingStatus = 200;
        completionRequests.clear();
        embeddingInputs.clear();
        authorizationHeaders.clear();
    }

    /** Answers each completion request with the given function of the request body. */
    public void onCompletion(Function<JsonNode, String> responder) {
        this.completionResponder = responder;
    }

    public void onEmbedding(Function<String, float[]> responder) {
        this.embeddingResponder = responder;
    }

    public void failCompletions(int status) {
        this.completionStatus = status;
    }

    public void failEmbeddings(int status) {
        this.embeddingStatus = status;
    }

    public List<JsonNode> completionRequests() {
        return List.copyOf(completionRequests);
    }

    public List<String> embeddingInputs() {
        return List.copyOf(embeddingInputs);
    }

    public List<String> authorizationHeaders() {
        return List.copyOf(authorizationHeaders);
    }

    // -------------------------------------------------------------------------

    /** The content of the last message in a chat completion request. */
    public static String lastMessage(JsonNode body) {
        JsonNode messages = body.path("messages");
        return messages.get(messages.size() - 1).path("content").asText();
    }

    /** The content of the first (system) message in a chat completion request. */
    public static String firstMessage(JsonNode body) {
        return body.path("messages").get(0).path("content").asText();
    }

    /** Unit vector along one axis: cosine distance 0 to itself, 1 to every other axis. */
    public static float[] axis(int index) {
        float[] v = new float[DIMENSIONS];
        v[index] = 1f;
        return v;
    }

    /** Deterministic non-zero vector derived from the text. */
    public static float[] hashVector(String text) {
        float[] v = new float[DIMENSIONS];
        v[Math.floorMod(text.hashCode(), DIMENSIONS)] = 1f;
        v[DIMENSIONS - 1] += 0.01f;
        return v;
    }

    // -------------------------------------------------------------------------

    private MockResponse handle(RecordedRequest request) throws IOException {
        String path = request.getPath() == null ? "" : request.getPath();
        authorizationHeaders.add(String.valueOf(request.getHeader("Authorization")));
        JsonNode body = JSON.readTree(request.getBody().readUtf8());
        if (path.endsWith("/v1/chat/completions")) {
            completionRequests.add(body);
            if (completionStatus != 200) {
                return new MockResponse().setResponseCode(completionStatus).setBody("{\"error\":\"fake\"}");
            }
            String content = completionResponder.apply(body);
            ObjectNode root = JSON.createObjectNode();
            ArrayNode choices = root.putArray("choices");
            choices.addObject().putObject("message").put("role", "assistant").put("content", content);
            return json(root);
        }
        if (path.endsWith("/v1/embeddings")) {
            String input = body.path("input").asText();
            embeddingInputs.add(input);
            if (embeddingStatus != 200) {
                return new MockResponse().setResponseCode(embeddingStatus).setBody("{\"error\":\"fake\"}");
            }
            float[] vector = embeddingResponder.apply(input);
            ObjectNode root = JSON.createObjectNode();
            ArrayNode embedding = root.putArray("data").addObject().putArray("embedding");
            for (float f : vector) {
                embedding.add(f);
            }
            return json(root);
        }
        return new MockResponse().setResponseCode(404);
    }

    private static MockResponse json(JsonNode node) throws IOException {
        return new MockResponse()
                .setHeader("Content-Type", "application/json")
                .setBody(JSON.writeValueAsString(node));
    }
}
