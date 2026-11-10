package com.apsconnect.api.community;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface CommentRepository extends JpaRepository<Comment, UUID> {

    /** A post's comments, oldest first, after the cursor. */
    @Query("""
            SELECT c FROM Comment c
            WHERE c.postId = :postId
              AND c.status = :status
              AND c.createdAt > :after
              AND c.authorId NOT IN :hiddenAuthors
            ORDER BY c.createdAt ASC
            """)
    List<Comment> findPage(@Param("postId") UUID postId,
                           @Param("status") ContentStatus status,
                           @Param("after") LocalDateTime after,
                           @Param("hiddenAuthors") Collection<UUID> hiddenAuthors,
                           Pageable pageable);
}
