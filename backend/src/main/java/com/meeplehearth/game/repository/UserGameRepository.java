package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.UserGame;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserGameRepository extends JpaRepository<UserGame, UUID> {

    Optional<UserGame> findByUserIdAndGameId(UUID userId, UUID gameId);

    // No N+1: JOIN FETCH game eagerly
    @Query("SELECT ug FROM UserGame ug JOIN FETCH ug.game WHERE ug.user.id = :userId AND ug.isOwned = true")
    List<UserGame> findOwnedByUserId(UUID userId);

    @Query("SELECT ug FROM UserGame ug JOIN FETCH ug.game WHERE ug.user.id = :userId AND ug.isWishlisted = true")
    List<UserGame> findWishlistedByUserId(UUID userId);

    @Query("SELECT ug FROM UserGame ug JOIN FETCH ug.game WHERE ug.user.id = :userId AND ug.isFavorited = true")
    List<UserGame> findFavoritedByUserId(UUID userId);

    @Query("SELECT ug FROM UserGame ug JOIN FETCH ug.game WHERE ug.user.id = :userId")
    List<UserGame> findAllByUserId(UUID userId);
}
