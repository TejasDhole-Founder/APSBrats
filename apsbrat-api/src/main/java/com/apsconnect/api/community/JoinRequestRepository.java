package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface JoinRequestRepository extends JpaRepository<JoinRequest, CommunityMember.Key> {

    /** The requests I've sent (to mark "Requested" in Discover). */
    List<JoinRequest> findByUserId(UUID userId);

    /** Pending requests for one community, oldest first (the owner's list). */
    List<JoinRequest> findByCommunityIdOrderByCreatedAtAsc(UUID communityId);
}
