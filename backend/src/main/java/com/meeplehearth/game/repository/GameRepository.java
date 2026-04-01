package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.Game;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GameRepository extends JpaRepository<Game, UUID>, JpaSpecificationExecutor<Game> {

    Optional<Game> findByBggId(Long bggId);

    List<Game> findByThumbnailUrlIsNull(Pageable pageable);

    List<Game> findByMinPlayersIsNull(Pageable pageable);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "gameDetail")
    List<Game> findByBggIdIn(Collection<Long> bggIds);

    /**
     * pg_trgm fuzzy search — handles typos, partial matches, and translated queries.
     * Returns up to 20 results ordered by best trigram similarity across name_en, name_zh, alias_names.
     * Requires V23 migration (pg_trgm extension + GIN indexes).
     */
    @Query(value = """
            SELECT id, bgg_id, name_en, year_published, thumbnail_url
            FROM games
            WHERE game_type = 'boardgame'
              AND (
                similarity(name_en, :query) > 0.1
                OR similarity(COALESCE(name_zh, ''), :query) > 0.1
                OR similarity(alias_names::text, :query) > 0.1
              )
            ORDER BY GREATEST(
                similarity(name_en, :query),
                similarity(COALESCE(name_zh, ''), :query),
                similarity(alias_names::text, :query)
            ) DESC
            LIMIT 20
            """, nativeQuery = true)
    List<GameSearchProjection> searchTrigram(@Param("query") String query);

    interface GameSearchProjection {
        UUID getId();
        Long getBggId();
        String getNameEn();
        Integer getYearPublished();
        String getThumbnailUrl();
    }
}
