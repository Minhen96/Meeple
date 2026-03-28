package com.meeplehearth.game.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.StringReader;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
public class BggApiClient {

    private static final int TIMEOUT_MS = 8000;
    private static final int POLL_RETRIES = 3;
    private static final long POLL_DELAY_MS = 2000;

    private final RestClient restClient;

    public BggApiClient() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(TIMEOUT_MS);
        factory.setReadTimeout(TIMEOUT_MS);

        this.restClient = RestClient.builder()
                .baseUrl("https://boardgamegeek.com/xmlapi2")
                .requestFactory(factory)
                .defaultHeader("User-Agent", "MeepleApp/1.0")
                .build();
    }

    @CircuitBreaker(name = "bgg", fallbackMethod = "searchFallback")
    public List<BggSearchResult> search(String query) {
        String xml = restClient.get()
                .uri("/search?query={q}&type=boardgame", query)
                .retrieve()
                .body(String.class);
        return parseSearchResults(xml);
    }

    @SuppressWarnings("unused")
    private List<BggSearchResult> searchFallback(String query, Exception e) {
        throw new BggUnavailableException("BGG search unavailable: " + e.getMessage());
    }

    @CircuitBreaker(name = "bgg", fallbackMethod = "getDetailFallback")
    public Optional<BggGameDetail> getDetail(Long bggId) {
        for (int attempt = 0; attempt < POLL_RETRIES; attempt++) {
            var response = restClient.get()
                    .uri("/thing?id={id}&stats=1", bggId)
                    .retrieve()
                    .toEntity(String.class);

            if (response.getStatusCode().value() == 202) {
                try {
                    Thread.sleep(POLL_DELAY_MS);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
                continue;
            }
            return parseGameDetail(response.getBody());
        }
        return Optional.empty();
    }

    @SuppressWarnings("unused")
    private Optional<BggGameDetail> getDetailFallback(Long bggId, Exception e) {
        throw new BggUnavailableException("BGG detail unavailable: " + e.getMessage());
    }

    // -------------------------------------------------------------------------
    // XML parsing
    // -------------------------------------------------------------------------

    private List<BggSearchResult> parseSearchResults(String xml) {
        List<BggSearchResult> results = new ArrayList<>();
        if (xml == null) return results;

        Document doc = parseXml(xml);
        NodeList items = doc.getElementsByTagName("item");

        for (int i = 0; i < items.getLength(); i++) {
            Element item = (Element) items.item(i);
            long bggId = Long.parseLong(item.getAttribute("id"));

            String title = null;
            NodeList names = item.getElementsByTagName("name");
            for (int j = 0; j < names.getLength(); j++) {
                Element name = (Element) names.item(j);
                if ("primary".equals(name.getAttribute("type"))) {
                    title = name.getAttribute("value");
                    break;
                }
            }
            if (title == null) continue;

            Integer year = null;
            NodeList yearNodes = item.getElementsByTagName("yearpublished");
            if (yearNodes.getLength() > 0) {
                String val = ((Element) yearNodes.item(0)).getAttribute("value");
                if (!val.isEmpty()) year = Integer.parseInt(val);
            }

            results.add(new BggSearchResult(bggId, title, year));
        }
        return results;
    }

    private Optional<BggGameDetail> parseGameDetail(String xml) {
        if (xml == null) return Optional.empty();

        Document doc = parseXml(xml);
        NodeList items = doc.getElementsByTagName("item");
        if (items.getLength() == 0) return Optional.empty();

        Element item = (Element) items.item(0);
        long bggId = Long.parseLong(item.getAttribute("id"));

        String title = null;
        NodeList names = item.getElementsByTagName("name");
        for (int j = 0; j < names.getLength(); j++) {
            Element name = (Element) names.item(j);
            if ("primary".equals(name.getAttribute("type"))) {
                title = name.getAttribute("value");
                break;
            }
        }

        String thumbnail   = textContent(item, "thumbnail");
        String image       = textContent(item, "image");
        String description = textContent(item, "description");
        Integer year = intAttr(item, "yearpublished");
        Integer minP = intAttr(item, "minplayers");
        Integer maxP = intAttr(item, "maxplayers");
        Integer minT = intAttr(item, "minplaytime");
        Integer maxT = intAttr(item, "maxplaytime");

        BigDecimal rating = null;
        BigDecimal weight = null;
        NodeList statsNodes = item.getElementsByTagName("ratings");
        if (statsNodes.getLength() > 0) {
            Element ratings = (Element) statsNodes.item(0);
            rating = decimalAttr(ratings, "average");
            weight = decimalAttr(ratings, "averageweight");
        }

        return Optional.of(new BggGameDetail(
                bggId, title, thumbnail, image, description,
                year, minP, maxP, minT, maxT, rating, weight
        ));
    }

    private String textContent(Element parent, String tagName) {
        NodeList nodes = parent.getElementsByTagName(tagName);
        if (nodes.getLength() == 0) return null;
        String text = nodes.item(0).getTextContent();
        return text.isBlank() ? null : text.strip();
    }

    private Integer intAttr(Element parent, String tagName) {
        NodeList nodes = parent.getElementsByTagName(tagName);
        if (nodes.getLength() == 0) return null;
        String val = ((Element) nodes.item(0)).getAttribute("value");
        if (val.isEmpty()) return null;
        try { return Integer.parseInt(val); } catch (NumberFormatException e) { return null; }
    }

    private BigDecimal decimalAttr(Element parent, String tagName) {
        NodeList nodes = parent.getElementsByTagName(tagName);
        if (nodes.getLength() == 0) return null;
        String val = ((Element) nodes.item(0)).getAttribute("value");
        if (val.isEmpty() || "0".equals(val)) return null;
        try { return new BigDecimal(val); } catch (NumberFormatException e) { return null; }
    }

    private Document parseXml(String xml) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            DocumentBuilder builder = factory.newDocumentBuilder();
            return builder.parse(new InputSource(new StringReader(xml)));
        } catch (Exception e) {
            throw new RuntimeException("Failed to parse BGG XML response", e);
        }
    }

    // -------------------------------------------------------------------------
    // Inner types
    // -------------------------------------------------------------------------

    public record BggSearchResult(Long bggId, String title, Integer yearPublished) {}

    public record BggGameDetail(
            Long bggId,
            String title,
            String thumbnailUrl,
            String imageUrl,
            String description,
            Integer yearPublished,
            Integer minPlayers,
            Integer maxPlayers,
            Integer minPlaytime,
            Integer maxPlaytime,
            BigDecimal bggRating,
            BigDecimal complexityWeight
    ) {}

    public static class BggUnavailableException extends RuntimeException {
        public BggUnavailableException(String message) {
            super(message);
        }
    }
}
