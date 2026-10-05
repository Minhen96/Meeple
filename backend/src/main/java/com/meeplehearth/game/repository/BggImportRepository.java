package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.BggImport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface BggImportRepository extends JpaRepository<BggImport, UUID> {

    @Modifying
    @Query(value = "DELETE FROM bgg_imports WHERE user_id = :userId", nativeQuery = true)
    int deleteAllByUserId(@Param("userId") UUID userId);
}
