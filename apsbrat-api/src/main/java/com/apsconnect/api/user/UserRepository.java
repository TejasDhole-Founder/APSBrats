package com.apsconnect.api.user;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    boolean existsByUsername(String username);

    boolean existsByPhone(String phone);

    boolean existsByEmail(String email);

    Optional<User> findByPhone(String phone);

    Optional<User> findByUsername(String username);

    List<User> findTop12ByOrderByCreatedAtDesc();

    List<User> findByCreatedAtAfterOrderByCreatedAtDesc(LocalDateTime since);

    @Query("""
            SELECT u FROM User u
            WHERE LOWER(u.fullName) LIKE LOWER(CONCAT('%', :term, '%'))
               OR LOWER(u.username) LIKE LOWER(CONCAT('%', :term, '%'))
               OR LOWER(u.city) LIKE LOWER(CONCAT('%', :term, '%'))
            """)
    List<User> search(@Param("term") String term);
}
