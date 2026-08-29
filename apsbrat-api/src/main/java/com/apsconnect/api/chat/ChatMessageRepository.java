package com.apsconnect.api.chat;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    List<ChatMessage> findAllByConversation_IdOrderByCreatedAtAsc(UUID conversationId);

    List<ChatMessage> findByConversation_IdOrderByCreatedAtDesc(UUID conversationId, Pageable pageable);

    List<ChatMessage> findByConversation_IdAndCreatedAtLessThanOrderByCreatedAtDesc(
            UUID conversationId, LocalDateTime cursor, Pageable pageable);

    Optional<ChatMessage> findTopByConversation_IdOrderByCreatedAtDesc(UUID conversationId);

    long countByConversation_IdAndSender_IdNotAndReadAtIsNull(UUID conversationId, UUID senderId);

    List<ChatMessage> findAllBySender_IdOrderByCreatedAtAsc(UUID senderId);

    @Modifying
    @Query("""
            UPDATE ChatMessage m
            SET m.readAt = :now
            WHERE m.conversation.id = :conversationId
              AND m.sender.id <> :currentUserId
              AND m.readAt IS NULL
            """)
    void markRead(@Param("conversationId") UUID conversationId,
                  @Param("currentUserId") UUID currentUserId,
                  @Param("now") LocalDateTime now);
}
