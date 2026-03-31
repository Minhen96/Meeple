package com.meeplehearth.game.service;

import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.repository.GameRepository;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.FileReader;
import java.io.Reader;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * Imports board game catalog from boardgames.csv (161k rows, Feb 2025).
 * CSV columns: Rank, Game_Id, Title, Description, Year, GeekRating, AvgRating, Voters, Link, Thumbnail
 *
 * After import, run POST /api/v1/games/hydrate-images to fill in players,
 * mechanics, categories, and all other BGG metadata.
 */
@Service
public class GameDataImportService {
    private static final Logger log = LoggerFactory.getLogger(GameDataImportService.class);
    private final GameRepository gameRepository;

    public GameDataImportService(GameRepository gameRepository) {
        this.gameRepository = gameRepository;
    }

    @Transactional
    public void runImport(String csvPath) throws Exception {
        log.info("Starting import from CSV: {}", csvPath);

        log.info("Clearing existing game catalog...");
        gameRepository.deleteAllInBatch();

        List<Game> toSave = new ArrayList<>();

        CSVFormat format = CSVFormat.DEFAULT.builder()
                .setHeader()
                .setSkipHeaderRecord(true)
                .setTrim(true)
                .setIgnoreSurroundingSpaces(true)
                .build();

        try (Reader reader = new FileReader(csvPath);
             CSVParser parser = format.parse(reader)) {

            for (CSVRecord record : parser) {
                Long bggId = parseLong(record.get("Game_Id"));
                if (bggId == null) continue;

                String title = record.get("Title");
                if (title == null || title.isBlank()) continue;

                Game g = new Game();
                g.setBggId(bggId);
                g.setGameType("boardgame");
                g.setNameEn(title);
                g.setYearPublished(parseInt(record.get("Year")));
                g.setBggRating(parseBigDecimal(record.get("GeekRating")));
                g.setUsersRated(parseInt(record.get("Voters")));
                g.setRank(parseInt(record.get("Rank")));

                String thumbnail = record.get("Thumbnail");
                if (thumbnail != null && !thumbnail.isBlank()) {
                    g.setThumbnailUrl(thumbnail.startsWith("//") ? "https:" + thumbnail : thumbnail);
                }

                // Create minimal GameDetail with description and BGG URL from CSV
                GameDetail gd = new GameDetail();
                gd.setGame(g);

                String description = record.get("Description");
                if (description != null && !description.isBlank()) {
                    gd.setDescription(description.replaceAll("<[^>]+>", "").strip());
                }

                String link = record.get("Link");
                if (link != null && !link.isBlank()) {
                    gd.setBggUrl(link.startsWith("http") ? link : "https://boardgamegeek.com" + link);
                }

                g.setGameDetail(gd);
                toSave.add(g);

                if (toSave.size() % 5000 == 0) {
                    log.info("Queued {} games so far...", toSave.size());
                }
            }
        }

        log.info("Saving {} new games in batches...", toSave.size());
        int batchSize = 1000;
        for (int i = 0; i < toSave.size(); i += batchSize) {
            int end = Math.min(i + batchSize, toSave.size());
            gameRepository.saveAll(toSave.subList(i, end));
            gameRepository.flush();
            log.info("Saved batch {}/{}", end, toSave.size());
        }
        log.info("Import completed. {} games imported.", toSave.size());
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
