package com.meeplehearth.ai.repository;

import com.meeplehearth.ai.entity.GameHowToPlay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface GameHowToPlayRepository extends JpaRepository<GameHowToPlay, UUID> {

    Optional<GameHowToPlay> findByGame_Id(UUID gameId);

    boolean existsByGame_Id(UUID gameId);
}
