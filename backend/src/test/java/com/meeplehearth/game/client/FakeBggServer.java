package com.meeplehearth.game.client;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Minimal stand-in for BGG's xmlapi2 {@code /collection} endpoint (JDK HttpServer, no extra test
 * dependency). Queue responses with {@link #enqueue}; when the queue is empty the server answers
 * 500. Records every request so tests can check the query and the Bearer token.
 */
public class FakeBggServer implements AutoCloseable {

    public record Reply(int status, String body) {
    }

    public record Request(String query, String authorization) {
    }

    private final HttpServer server;
    private final ConcurrentLinkedQueue<Reply> replies = new ConcurrentLinkedQueue<>();
    private final List<Request> requests = new CopyOnWriteArrayList<>();

    public FakeBggServer() throws IOException {
        server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), 0), 0);
        server.createContext("/xmlapi2/collection", this::handle);
        server.start();
    }

    public String baseUrl() {
        return "http://127.0.0.1:" + server.getAddress().getPort() + "/xmlapi2";
    }

    public FakeBggServer enqueue(int status, String body) {
        replies.add(new Reply(status, body));
        return this;
    }

    public List<Request> requests() {
        return requests;
    }

    public void reset() {
        replies.clear();
        requests.clear();
    }

    private void handle(HttpExchange exchange) throws IOException {
        requests.add(new Request(exchange.getRequestURI().getRawQuery(),
                exchange.getRequestHeaders().getFirst("Authorization")));
        Reply reply = replies.poll();
        if (reply == null) reply = new Reply(500, "<error/>");
        byte[] bytes = reply.body() == null ? new byte[0] : reply.body().getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "text/xml; charset=utf-8");
        exchange.sendResponseHeaders(reply.status(), bytes.length == 0 ? -1 : bytes.length);
        if (bytes.length > 0) {
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(bytes);
            }
        }
        exchange.close();
    }

    /** A collection document with the given (bggId, name) pairs; thumbnails are protocol-relative. */
    public static String collection(Object... idNamePairs) {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<items totalitems=\"")
                .append(idNamePairs.length / 2).append("\">");
        for (int i = 0; i < idNamePairs.length; i += 2) {
            sb.append("<item objecttype=\"thing\" objectid=\"").append(idNamePairs[i])
                    .append("\" subtype=\"boardgame\" collid=\"").append(i).append("\">")
                    .append("<name sortindex=\"1\">").append(idNamePairs[i + 1]).append("</name>")
                    .append("<yearpublished>2015</yearpublished>")
                    .append("<image>//cf.geekdo-images.com/").append(idNamePairs[i]).append(".jpg</image>")
                    .append("<thumbnail>//cf.geekdo-images.com/t").append(idNamePairs[i]).append(".jpg</thumbnail>")
                    .append("<status own=\"1\"/><numplays>0</numplays></item>");
        }
        return sb.append("</items>").toString();
    }

    public static final String QUEUED =
            "<message>Your request for this collection has been accepted and will be processed. "
                    + "Please try again later for access.</message>";

    public static final String INVALID_USER =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?><errors><error><message>Invalid username specified</message>"
                    + "</error></errors>";

    @Override
    public void close() {
        server.stop(0);
    }
}
