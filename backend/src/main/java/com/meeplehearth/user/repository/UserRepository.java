package com.meeplehearth.user.repository;

import com.meeplehearth.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmailIgnoreCase(String email);

    Optional<User> findByUsernameIgnoreCase(String username);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByUsernameIgnoreCase(String username);

    Optional<User> findByGoogleId(String googleId);

    Page<User> findByIdInAndDeletedAtIsNull(Collection<UUID> ids, Pageable pageable);

    @Query("""
            SELECT u FROM User u
            WHERE u.deletedAt IS NULL
              AND (LOWER(u.username) LIKE LOWER(CONCAT('%', :q, '%'))
                   OR LOWER(u.displayName) LIKE LOWER(CONCAT('%', :q, '%')))
            ORDER BY u.username ASC
            """)
    Page<User> searchByUsernameOrDisplayName(String q, Pageable pageable);

    @Query("""
            SELECT u FROM User u
            WHERE u.deletedAt IS NULL
              AND u.id <> :excludeId
              AND u.id NOT IN :excludeIds
            ORDER BY u.createdAt DESC
            """)
    Page<User> findSuggestions(UUID excludeId, Collection<UUID> excludeIds, Pageable pageable);
}
