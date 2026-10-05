package com.meeplehearth.report.repository;

import com.meeplehearth.report.entity.Report;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ReportRepository extends JpaRepository<Report, UUID> {

    /** Idempotent per (reporter, target): returns 1 when stored, 0 when already reported. */
    @Modifying
    @Query(value = """
            INSERT INTO reports (reporter_id, target_type, target_id, reason)
            VALUES (:reporterId, :targetType, :targetId, :reason)
            ON CONFLICT (reporter_id, target_type, target_id) DO NOTHING
            """, nativeQuery = true)
    int insertIfAbsent(@Param("reporterId") UUID reporterId, @Param("targetType") String targetType,
                       @Param("targetId") UUID targetId, @Param("reason") String reason);

    @Query(value = "SELECT EXISTS (SELECT 1 FROM post_comments WHERE id = :id AND deleted_at IS NULL)",
            nativeQuery = true)
    boolean commentExists(@Param("id") UUID id);

    @Query(value = "SELECT EXISTS (SELECT 1 FROM posts WHERE id = :id AND deleted_at IS NULL)", nativeQuery = true)
    boolean postExists(@Param("id") UUID id);

    @Query(value = "SELECT EXISTS (SELECT 1 FROM users WHERE id = :id AND deleted_at IS NULL)", nativeQuery = true)
    boolean userExists(@Param("id") UUID id);
}
