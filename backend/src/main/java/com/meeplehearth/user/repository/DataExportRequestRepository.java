package com.meeplehearth.user.repository;

import com.meeplehearth.user.entity.DataExportRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface DataExportRequestRepository extends JpaRepository<DataExportRequest, UUID> {

    Optional<DataExportRequest> findFirstByUserIdOrderByCreatedAtDesc(UUID userId);

    /** Moves a request from PENDING to RUNNING; returns 1 only for the single worker that claims it. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE DataExportRequest r SET r.status = com.meeplehearth.user.entity.DataExportRequest.Status.RUNNING "
            + "WHERE r.id = :id AND r.status = com.meeplehearth.user.entity.DataExportRequest.Status.PENDING")
    int claim(@Param("id") UUID id);
}
