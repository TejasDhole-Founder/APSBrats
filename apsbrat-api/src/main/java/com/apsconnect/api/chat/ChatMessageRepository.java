package com.apsconnect.api.chat;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    List<ChatMessage> findByConversation_IdOrderByCreatedAtDesc(UUID conversationId, Pageable pageable);
    boolean existsByConversation_IdAndSender_Id(UUID conversationId, UUID senderId);

    List<ChatMessage> findByConversation_IdAndCreatedAtLessThanOrderByCreatedAtDesc(
            UUID conversationId, LocalDateTime cursor, Pageable pageable);

    Optional<ChatMessage> findTopByConversation_IdOrderByCreatedAtDesc(UUID conversationId);

    long countByConversation_IdAndSender_IdNotAndReadAtIsNull(UUID conversationId, UUID myUserId);

    @Modifying
    @Transactional
    @Query("update ChatMessage m set m.readAt = :now "
            + "where m.conversation.id = :conversationId "
            + "and m.sender.id <> :myUserId "
            + "and m.readAt is null")
    int markRead(@Param("conversationId") UUID conversationId,
                 @Param("myUserId") UUID myUserId,
                 @Param("now") LocalDateTime now);
}