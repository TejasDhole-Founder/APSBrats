package com.apsconnect.api.chat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    Optional<Conversation> findByUserA_IdAndUserB_Id(UUID userAId, UUID userBId);

    /** Both participants fetched in the same query, so building the list costs no extra user lookups. */
    @Query("select c from Conversation c join fetch c.userA join fetch c.userB "
            + "where (c.userA.id = :userId or c.userB.id = :userId) "
            + "and c.lastMessageAt is not null "
            + "order by c.lastMessageAt desc")
    List<Conversation> findActiveFor(@Param("userId") UUID userId);
}