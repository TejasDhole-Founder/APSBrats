package com.apsconnect.api.user.history;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface UserSchoolHistoryRepository extends JpaRepository<UserSchoolHistory, UUID> {
    void deleteAllByUser_Id(UUID userId);

    List<UserSchoolHistory> findAllByUser_Id(UUID userId);

    // Batch loader (one query, school eager-joined) to avoid N+1 when building many PersonDtos.
    @Query("SELECT h FROM UserSchoolHistory h JOIN FETCH h.school WHERE h.user.id IN :ids")
    List<UserSchoolHistory> findAllWithSchoolByUserIds(@Param("ids") Collection<UUID> ids);

    // ── Classmates: same school + same section, years and classes overlap ──────
    // Sessions run April→March, so an entry ending in 2019 and one starting in
    // 2019 do NOT overlap (strict <). Entries without a section never match.

    String CLASSMATE_MATCH = """
            FROM user_school_history mine
            JOIN user_school_history h
              ON h.school_id = mine.school_id
             AND h.section IS NOT NULL AND h.section = mine.section
             AND h.batch_start < mine.batch_end AND mine.batch_start < h.batch_end
             AND h.class_from <= mine.class_to AND mine.class_from <= h.class_to
            JOIN users u ON u.id = h.user_id AND u.deleted_at IS NULL
            WHERE mine.user_id = :me AND h.user_id <> :me
            """;

    @Query(value = "SELECT DISTINCT h.user_id " + CLASSMATE_MATCH, nativeQuery = true)
    List<UUID> findClassmateIds(@Param("me") UUID me);

    @Query(value = "SELECT DISTINCT h.user_id " + CLASSMATE_MATCH + " AND mine.id = :entryId", nativeQuery = true)
    List<UUID> findClassmateIdsForEntry(@Param("me") UUID me, @Param("entryId") UUID entryId);

    @Query(value = "SELECT COUNT(DISTINCT h.user_id) " + CLASSMATE_MATCH, nativeQuery = true)
    long countClassmates(@Param("me") UUID me);

    // ── Schoolmates: anyone who attended one of my schools ────────────────────

    String SCHOOLMATE_MATCH = """
            FROM user_school_history mine
            JOIN user_school_history h ON h.school_id = mine.school_id
            JOIN users u ON u.id = h.user_id AND u.deleted_at IS NULL
            WHERE mine.user_id = :me AND h.user_id <> :me
            """;

    @Query(value = "SELECT DISTINCT h.user_id " + SCHOOLMATE_MATCH
            + " AND (:batchOnly = FALSE OR h.batch_end = mine.batch_end)", nativeQuery = true)
    List<UUID> findSchoolmateIds(@Param("me") UUID me, @Param("batchOnly") boolean batchOnly);

    @Query(value = "SELECT DISTINCT h.user_id " + SCHOOLMATE_MATCH
            + " AND mine.id = :entryId AND (:batchOnly = FALSE OR h.batch_end = mine.batch_end)", nativeQuery = true)
    List<UUID> findSchoolmateIdsForEntry(@Param("me") UUID me, @Param("entryId") UUID entryId,
                                         @Param("batchOnly") boolean batchOnly);

    @Query(value = "SELECT COUNT(DISTINCT h.user_id) " + SCHOOLMATE_MATCH, nativeQuery = true)
    long countSchoolmates(@Param("me") UUID me);

    /** Of the given ids, those who passed out of one of my schools in the same year as me. */
    @Query(value = """
            SELECT DISTINCT h.user_id
            FROM user_school_history mine
            JOIN user_school_history h
              ON h.school_id = mine.school_id AND h.batch_end = mine.batch_end
            WHERE mine.user_id = :me AND h.user_id IN (:ids)
            """, nativeQuery = true)
    List<UUID> findSameBatchIds(@Param("me") UUID me, @Param("ids") Collection<UUID> ids);
}
