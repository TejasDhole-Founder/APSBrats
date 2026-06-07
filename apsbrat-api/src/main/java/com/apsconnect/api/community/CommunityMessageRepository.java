package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CommunityMessageRepository extends JpaRepository<CommunityMessage, UUID> {
    List<CommunityMessage> findAllByCommunity_IdOrderByCreatedAtAsc(UUID communityId);

    Optional<CommunityMessage> findTopByCommunity_IdOrderByCreatedAtDesc(UUID communityId);

    long countByCommunity_IdAndCreatedAtAfter(UUID communityId, LocalDateTime after);

    long countByCommunity_Id(UUID communityId);
}
