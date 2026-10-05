package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.GameDetail;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * GameDetail shares its primary key with Game (game_details.game_id = games.id),
 * so findById(gameId) / findAllById(gameIds) load details explicitly when needed.
 */
@Repository
public interface GameDetailRepository extends JpaRepository<GameDetail, UUID> {
}
