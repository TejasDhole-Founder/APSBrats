package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CommunityMemberRepository extends JpaRepository<CommunityMember, UUID> {
    List<CommunityMember> findAllByUser_IdOrderByJoinedAtDesc(UUID userId);


    // Only the avatars we actually render — avoids loading the full membership.
    List<CommunityMember> findTop5ByCommunity_IdOrderByJoinedAtAsc(UUID communityId);

    Optional<CommunityMember> findByCommunity_IdAndUser_Id(UUID communityId, UUID userId);

    long countByCommunity_Id(UUID communityId);

    boolean existsByCommunity_IdAndUser_Id(UUID communityId, UUID userId);
}
