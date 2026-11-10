package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface CommunityMemberRepository extends JpaRepository<CommunityMember, CommunityMember.Key> {

    /** Every community this person is in. */
    List<CommunityMember> findByUserId(UUID userId);

    /** Ids only, for the per-request "my communities" / "communities I own" checks. */
    @Query("SELECT m.communityId FROM CommunityMember m WHERE m.userId = :userId")
    List<UUID> findCommunityIdsByUserId(@Param("userId") UUID userId);

    @Query("SELECT m.communityId FROM CommunityMember m WHERE m.userId = :userId AND m.role = :role")
    List<UUID> findCommunityIdsByUserIdAndRole(@Param("userId") UUID userId, @Param("role") MemberRole role);

    /** Members active since [since] who share their activity (no settings row = shared). */
    @Query(value = """
            SELECT COUNT(*) FROM community_members cm
            JOIN users u ON u.id = cm.user_id
            LEFT JOIN user_settings s ON s.user_id = u.id
            WHERE cm.community_id = :communityId
              AND u.last_active_at > :since
              AND COALESCE(s.show_activity, TRUE)
            """, nativeQuery = true)
    long countActiveSince(@Param("communityId") UUID communityId, @Param("since") java.time.LocalDateTime since);

    /** Which of these people are members (e.g. the ones connected right now). */
    @Query("SELECT m.userId FROM CommunityMember m WHERE m.communityId = :communityId AND m.userId IN :userIds")
    List<UUID> findUserIdsIn(@Param("communityId") UUID communityId, @Param("userIds") Collection<UUID> userIds);
}