package com.apsconnect.api.chat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    Optional<Conversation> findByUserA_IdAndUserB_Id(UUID userAId, UUID userBId);

    @Query("select c from Conversation c "
            + "where (c.userA.id = :userId or c.userB.id = :userId) "
            + "and c.lastMessageAt is not null "
            + "order by c.lastMessageAt desc")
    List<Conversation> findActiveFor(@Param("userId") UUID userId);

    List<Conversation> findByUserA_IdAndLastMessageAtIsNotNull(UUID myId);

    List<Conversation> findByUserB_IdAndLastMessageAtIsNotNull(UUID myId);
}