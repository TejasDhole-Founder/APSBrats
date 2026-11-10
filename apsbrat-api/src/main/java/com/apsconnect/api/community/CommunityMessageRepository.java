package com.apsconnect.api.community;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface CommunityMessageRepository extends JpaRepository<CommunityMessage, UUID> {

    /** Newest first, older than the cursor; ask for one extra row to know if there's more. */
    @Query("""
            SELECT m FROM CommunityMessage m
            WHERE m.communityId = :communityId
              AND m.status = :status
              AND m.createdAt < :before
              AND m.senderId NOT IN :hiddenSenders
            ORDER BY m.createdAt DESC
            """)
    List<CommunityMessage> findPage(@Param("communityId") UUID communityId,
                                    @Param("status") ContentStatus status,
                                    @Param("before") LocalDateTime before,
                                    @Param("hiddenSenders") Collection<UUID> hiddenSenders,
                                    Pageable pageable);

    /** Messages from others since I last read the chat. */
    @Query("""
            SELECT COUNT(m) FROM CommunityMessage m
            WHERE m.communityId = :communityId
              AND m.status = :status
              AND m.senderId <> :me
              AND m.senderId NOT IN :hiddenSenders
              AND m.createdAt > :since
            """)
    long countUnread(@Param("communityId") UUID communityId,
                     @Param("status") ContentStatus status,
                     @Param("me") UUID me,
                     @Param("hiddenSenders") Collection<UUID> hiddenSenders,
                     @Param("since") LocalDateTime since);
}
