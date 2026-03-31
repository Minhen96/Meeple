package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.Game;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
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
}
