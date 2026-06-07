package com.apsconnect.api.chat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    Optional<Conversation> findByUserA_IdAndUserB_Id(UUID userAId, UUID userBId);

    @Query("""
            SELECT c FROM Conversation c
            WHERE c.userA.id = :userId OR c.userB.id = :userId
            ORDER BY COALESCE(c.lastMessageAt, c.createdAt) DESC
            """)
    List<Conversation> findAllForUser(@Param("userId") UUID userId);
}
