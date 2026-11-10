package com.apsconnect.api.safety;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ReportRepository extends JpaRepository<Report, UUID> {
    List<Report> findByStatusOrderByCreatedAtDesc(String status);

    List<Report> findByOrderByCreatedAtDesc();

    /** This person's earlier report of the same thing, if any (a repeat counts once). */
    @org.springframework.data.jpa.repository.Query(value = """
            SELECT id FROM reports
            WHERE reporter_id = :reporterId AND target_type = :type
              AND COALESCE(target_id, target_user_id) = :target
            LIMIT 1
            """, nativeQuery = true)
    java.util.Optional<UUID> findExisting(@org.springframework.data.repository.query.Param("reporterId") UUID reporterId,
                                         @org.springframework.data.repository.query.Param("type") String type,
                                         @org.springframework.data.repository.query.Param("target") UUID target);

    /** How many different people reported this post/comment (one person reporting twice counts once). */
    @org.springframework.data.jpa.repository.Query("""
            SELECT COUNT(DISTINCT r.reporter.id) FROM Report r
            WHERE r.targetType = :type AND r.targetId = :targetId
            """)
    long countDistinctReporters(@org.springframework.data.repository.query.Param("type") ReportTargetType type,
                                @org.springframework.data.repository.query.Param("targetId") java.util.UUID targetId);
}
