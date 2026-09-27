package com.apsconnect.api.user;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    org.springframework.data.domain.Page<User> findAllByDeletedAtNull(org.springframework.data.domain.Pageable pageable);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    Optional<User> findByEmail(String email);

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

    /**
     * People search in ONE statement: filters first, then name ranking, then paging.
     * <ul>
     *   <li>{@code firstLike} ("%amit%") is a trigram-indexed pre-filter on name/username;
     *       {@code wordPattern} then requires every typed word to start a word of
     *       "name username" (so "amit pra" finds Amit Prasad, not Sumit Prakash).</li>
     *   <li>School filters must all hold on the SAME school entry (EXISTS sub-select).</li>
     *   <li>Rank: exact name, name starts with the text, word-prefix on name, username match, then A→Z.</li>
     * </ul>
     * Null parameters mean "no filter". The viewer is always excluded.
     */
    @Query(value = """
            SELECT u.* FROM users u
            WHERE u.deleted_at IS NULL
              AND u.id <> :viewerId
              AND (CAST(:firstLike AS text) IS NULL
                   OR LOWER(u.full_name) LIKE CAST(:firstLike AS text)
                   OR LOWER(u.username) LIKE CAST(:firstLike AS text))
              AND (CAST(:wordPattern AS text) IS NULL
                   OR (LOWER(u.full_name) || ' ' || LOWER(u.username)) ~ CAST(:wordPattern AS text))
              AND (CAST(:status AS text) IS NULL OR CAST(u.current_status AS text) = CAST(:status AS text))
              AND (CAST(:city AS text) IS NULL OR LOWER(u.city) = CAST(:city AS text))
              AND (:scopeMine = FALSE OR EXISTS (
                    SELECT 1 FROM user_school_history theirs
                    JOIN user_school_history mine ON mine.school_id = theirs.school_id
                    WHERE theirs.user_id = u.id AND mine.user_id = :viewerId))
              AND (:usesHistory = FALSE OR EXISTS (
                    SELECT 1 FROM user_school_history h
                    WHERE h.user_id = u.id
                      AND (CAST(:schoolId AS uuid) IS NULL OR h.school_id = CAST(:schoolId AS uuid))
                      AND (CAST(:batch AS smallint) IS NULL OR h.batch_end = CAST(:batch AS smallint))
                      AND (CAST(:classTo AS smallint) IS NULL OR h.class_to = CAST(:classTo AS smallint))
                      AND (CAST(:section AS text) IS NULL OR h.section = CAST(:section AS text))
                      AND (CAST(:stream AS text) IS NULL OR h.stream = CAST(:stream AS text))))
            ORDER BY
              CASE
                WHEN CAST(:q AS text) IS NULL THEN 0
                WHEN LOWER(u.full_name) = CAST(:q AS text) THEN 0
                WHEN LOWER(u.full_name) LIKE CAST(:q AS text) || '%' THEN 1
                WHEN LOWER(u.full_name) ~ CAST(:wordPattern AS text) THEN 2
                ELSE 3
              END,
              u.full_name,
              u.id
            LIMIT :limit OFFSET :offset
            """, nativeQuery = true)
    List<User> searchPeople(@Param("viewerId") UUID viewerId,
                            @Param("q") String q,
                            @Param("firstLike") String firstLike,
                            @Param("wordPattern") String wordPattern,
                            @Param("scopeMine") boolean scopeMine,
                            @Param("usesHistory") boolean usesHistory,
                            @Param("schoolId") UUID schoolId,
                            @Param("batch") Short batch,
                            @Param("classTo") Short classTo,
                            @Param("section") String section,
                            @Param("stream") String stream,
                            @Param("status") String status,
                            @Param("city") String city,
                            @Param("limit") int limit,
                            @Param("offset") int offset);
}
