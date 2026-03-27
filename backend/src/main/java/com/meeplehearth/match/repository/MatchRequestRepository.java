package com.meeplehearth.match.repository;

import com.meeplehearth.match.entity.MatchRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

// Phase 2 repository — stub only
@Repository
public interface MatchRequestRepository extends JpaRepository<MatchRequest, UUID> {
}
