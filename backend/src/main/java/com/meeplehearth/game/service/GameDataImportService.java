package com.meeplehearth.game.service;

import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.repository.GameRepository;
import jakarta.persistence.EntityManager;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.Reader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Imports board game catalog from boardgames.csv (161k rows, Feb 2025).
 * CSV columns: Rank, Game_Id, Title, Description, Year, GeekRating, AvgRating, Voters, Link, Thumbnail
 *
 * The CSV is streamed and persisted in chunks of {@value #CHUNK_SIZE}, each chunk in its own
 * transaction (flush + clear afterwards so the persistence context stays small).
 *
 * Existing games are NEVER deleted (games are referenced by collections, posts, events,
 * rulebooks, ...). Rows whose bgg_id already exists only get their CSV-owned ranking
 * fields refreshed (rank, rating, voters, year); new bgg_ids are inserted.
 *
 * After import, run POST /api/v1/games/hydrate-images to fill in players,
 * mechanics, categories, and all other BGG metadata.
 */
@Service
public class GameDataImportService {
    private static final Logger log = LoggerFactory.getLogger(GameDataImportService.class);
    static final int CHUNK_SIZE = 1000;

    private final GameRepository gameRepository;
    private final EntityManager entityManager;
    private final TransactionTemplate transactionTemplate;

    public GameDataImportService(GameRepository gameRepository,
                                 EntityManager entityManager,
                                 PlatformTransactionManager transactionManager) {
        this.gameRepository = gameRepository;
        this.entityManager = entityManager;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    /** CSV-derived values for one game row. */
    private record CsvGame(Long bggId, String title, Integer year, BigDecimal rating, Integer voters,
                           Integer rank, String thumbnail, String description, String bggUrl) {}

    public void runImport(String csvPath) throws Exception {
        log.info("Starting import from CSV: {}", csvPath);

        CSVFormat format = CSVFormat.DEFAULT.builder()
                .setHeader()
                .setSkipHeaderRecord(true)
                .setTrim(true)
                .setIgnoreSurroundingSpaces(true)
                .build();

        Set<Long> seen = new HashSet<>();
        List<CsvGame> chunk = new ArrayList<>(CHUNK_SIZE);
        int[] totals = new int[2]; // [inserted, updated]
        int rows = 0;

        // InputStreamReader replaces malformed bytes instead of aborting the whole import
        try (Reader reader = new BufferedReader(new InputStreamReader(
                     Files.newInputStream(Path.of(csvPath)), StandardCharsets.UTF_8));
             CSVParser parser = format.parse(reader)) {

            for (CSVRecord record : parser) {
                CsvGame row = parseRow(record);
                if (row == null || !seen.add(row.bggId())) continue;
                chunk.add(row);
                rows++;

                if (chunk.size() >= CHUNK_SIZE) {
                    persistChunk(chunk, totals);
                    chunk.clear();
                    log.info("Imported {} rows so far ({} new, {} updated)...", rows, totals[0], totals[1]);
                }
            }
        }
        if (!chunk.isEmpty()) {
            persistChunk(chunk, totals);
        }
        log.info("Import completed. {} rows processed: {} new games, {} existing games updated.",
                rows, totals[0], totals[1]);
    }

    private void persistChunk(List<CsvGame> chunk, int[] totals) {
        transactionTemplate.executeWithoutResult(status -> {
            Map<Long, Game> existing = gameRepository
                    .findByBggIdIn(chunk.stream().map(CsvGame::bggId).toList())
                    .stream()
                    .collect(Collectors.toMap(Game::getBggId, Function.identity()));

            for (CsvGame row : chunk) {
                Game g = existing.get(row.bggId());
                if (g != null) {
                    // Upsert: refresh only CSV-owned ranking fields; keep hydrated data and user links
                    if (row.rank() != null)   g.setRank(row.rank());
                    if (row.rating() != null) g.setBggRating(row.rating());
                    if (row.voters() != null) g.setUsersRated(row.voters());
                    if (row.year() != null)   g.setYearPublished(row.year());
                    totals[1]++;
                    continue;
                }

                g = new Game();
                g.setBggId(row.bggId());
                g.setGameType("boardgame");
                g.setNameEn(row.title());
                g.setYearPublished(row.year());
                g.setBggRating(row.rating());
                g.setUsersRated(row.voters());
                g.setRank(row.rank());
                g.setThumbnailUrl(row.thumbnail());
                entityManager.persist(g);

                // Minimal GameDetail with description and BGG URL from CSV
                GameDetail gd = new GameDetail();
                gd.setGame(g);
                gd.setDescription(row.description());
                gd.setBggUrl(row.bggUrl());
                entityManager.persist(gd);
                totals[0]++;
            }
            entityManager.flush();
            entityManager.clear();
        });
    }

    private CsvGame parseRow(CSVRecord record) {
        Long bggId = parseLong(record.get("Game_Id"));
        if (bggId == null) return null;

        String title = record.get("Title");
        if (title == null || title.isBlank()) return null;

        String thumbnail = record.get("Thumbnail");
        if (thumbnail != null && !thumbnail.isBlank()) {
            thumbnail = thumbnail.startsWith("//") ? "https:" + thumbnail : thumbnail;
        } else {
            thumbnail = null;
        }

        String description = record.get("Description");
        description = (description != null && !description.isBlank())
                ? description.replaceAll("<[^>]+>", "").strip()
                : null;

        String link = record.get("Link");
        String bggUrl = (link != null && !link.isBlank())
                ? (link.startsWith("http") ? link : "https://boardgamegeek.com" + link)
                : null;

        return new CsvGame(bggId, title, parseInt(record.get("Year")),
                parseBigDecimal(record.get("GeekRating")), parseInt(record.get("Voters")),
                parseInt(record.get("Rank")), thumbnail, description, bggUrl);
    }

    private Long parseLong(String val) {
        if (val == null || val.isBlank()) return null;
        try { return Long.parseLong(val.trim()); } catch (NumberFormatException e) { return null; }
    }

    private Integer parseInt(String val) {
        if (val == null || val.isBlank()) return null;
        try { return (int) Math.round(Double.parseDouble(val.trim())); } catch (NumberFormatException e) { return null; }
    }

    private BigDecimal parseBigDecimal(String val) {
        if (val == null || val.isBlank()) return null;
        try { return new BigDecimal(val.trim()); } catch (NumberFormatException e) { return null; }
    }
}
