package com.apsconnect.api.community;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public interface CommunityEventRepository extends JpaRepository<CommunityEvent, UUID> {

    /** Not over yet (ends now or later), including ones in progress. Soonest first. */
    @Query("""
            SELECT e FROM CommunityEvent e
            WHERE e.communityId = :communityId
              AND e.endsAt >= :from
            ORDER BY e.startsAt ASC
            """)
    List<CommunityEvent> findUpcoming(@Param("communityId") UUID communityId,
                                      @Param("from") LocalDateTime from,
                                      Pageable pageable);

    /** Already over. Most recent first. */
    @Query("""
            SELECT e FROM CommunityEvent e
            WHERE e.communityId = :communityId
              AND e.endsAt < :from
            ORDER BY e.startsAt DESC
            """)
    List<CommunityEvent> findPast(@Param("communityId") UUID communityId,
                                  @Param("from") LocalDateTime from,
                                  Pageable pageable);
}
