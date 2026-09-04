package com.apsconnect.api.chat;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.realtime.RealtimeService;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.util.CursorSupport;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationRepository conversationRepository;
    private final ChatMessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final UserBlockRepository blockRepository;
    private final RealtimeService realtimeService;

    @Transactional(readOnly = true)
    public List<ConversationDto> listConversations(UUID currentUserId) {
        List<Conversation> conversations = conversationRepository.findAllForUser(currentUserId);
        // Batch-build the "other participant" PersonDtos once.
        List<User> others = conversations.stream().map(c -> other(c, currentUserId)).toList();
        Map<UUID, PersonDto> byId = personService.toPeople(others).stream()
                .collect(Collectors.toMap(PersonDto::id, Function.identity(), (a, b) -> a));

        return conversations.stream()
                .map(c -> toDto(c, currentUserId, byId.get(other(c, currentUserId).getId())))
                .toList();
    }

    @Transactional
    public ConversationDto getOrCreateWith(UUID currentUserId, UUID otherUserId) {
        if (currentUserId.equals(otherUserId)) {
            throw new AppException("Cannot open a chat with yourself", HttpStatus.BAD_REQUEST);
        }
        userRepository.findById(otherUserId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        ensureNotBlocked(currentUserId, otherUserId);
        Conversation conversation = findOrCreate(currentUserId, otherUserId);
        PersonDto other = personService.toPerson(other(conversation, currentUserId));
        return toDto(conversation, currentUserId, other);
    }

    @Transactional(readOnly = true)
    public CursorPage<ChatMessageDto> messages(UUID currentUserId, UUID conversationId, String cursor, int limit) {
        ensureParticipant(currentUserId, conversationId);
        int pageSize = CursorSupport.clampLimit(limit);
        var pageable = PageRequest.of(0, pageSize + 1);
        LocalDateTime before = CursorSupport.decode(cursor);

        List<ChatMessage> rows = before == null
                ? messageRepository.findByConversation_IdOrderByCreatedAtDesc(conversationId, pageable)
                : messageRepository.findByConversation_IdAndCreatedAtLessThanOrderByCreatedAtDesc(
                        conversationId, before, pageable);

        boolean hasMore = rows.size() > pageSize;
        if (hasMore) {
            rows = rows.subList(0, pageSize);
        }
        String nextCursor = hasMore && !rows.isEmpty()
                ? CursorSupport.encode(rows.get(rows.size() - 1).getCreatedAt())
                : null;

        // rows are newest-first; return ascending for display.
        List<ChatMessageDto> items = new ArrayList<>(rows.stream()
                .map(m -> new ChatMessageDto(
                        m.getId(),
                        m.getSender().getId(),
                        m.getBody(),
                        m.getSender().getId().equals(currentUserId),
                        m.getCreatedAt()))
                .toList());
        java.util.Collections.reverse(items);
        return CursorPage.of(items, nextCursor, hasMore);
    }

    @Transactional
    public ChatMessageDto send(UUID currentUserId, UUID conversationId, String body) {
        Conversation conversation = ensureParticipant(currentUserId, conversationId);
        ensureNotBlocked(currentUserId, other(conversation, currentUserId).getId());
        User sender = userRepository.findById(currentUserId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        ChatMessage message = new ChatMessage();
        message.setConversation(conversation);
        message.setSender(sender);
        message.setBody(body.trim());
        message.setCreatedAt(LocalDateTime.now());
        message = messageRepository.save(message);

        conversation.setLastMessageAt(message.getCreatedAt());
        conversationRepository.save(conversation);

        UUID recipientId = other(conversation, currentUserId).getId();
        ChatMessageDto recipientView = new ChatMessageDto(
                message.getId(), sender.getId(), message.getBody(), false, message.getCreatedAt());
        realtimeService.publishDirectMessage(recipientId, recipientView);

        return new ChatMessageDto(message.getId(), sender.getId(), message.getBody(), true, message.getCreatedAt());
    }

    @Transactional
    public void markRead(UUID currentUserId, UUID conversationId) {
        ensureParticipant(currentUserId, conversationId);
        messageRepository.markRead(conversationId, currentUserId, LocalDateTime.now());
    }

    private Conversation findOrCreate(UUID currentUserId, UUID otherUserId) {
        boolean currentIsLow = currentUserId.compareTo(otherUserId) <= 0;
        UUID low = currentIsLow ? currentUserId : otherUserId;
        UUID high = currentIsLow ? otherUserId : currentUserId;

        return conversationRepository.findByUserA_IdAndUserB_Id(low, high)
                .orElseGet(() -> {
                    Conversation c = new Conversation();
                    c.setUserA(userRepository.getReferenceById(low));
                    c.setUserB(userRepository.getReferenceById(high));
                    c.setCreatedAt(LocalDateTime.now());
                    return conversationRepository.save(c);
                });
    }

    private Conversation ensureParticipant(UUID currentUserId, UUID conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
        if (!conversation.getUserA().getId().equals(currentUserId)
                && !conversation.getUserB().getId().equals(currentUserId)) {
            throw new AppException("Not a participant of this conversation", HttpStatus.FORBIDDEN);
        }
        return conversation;
    }

    private ConversationDto toDto(Conversation c, UUID currentUserId, PersonDto other) {
        var last = messageRepository.findTopByConversation_IdOrderByCreatedAtDesc(c.getId()).orElse(null);
        long unreadCount = messageRepository
                .countByConversation_IdAndSender_IdNotAndReadAtIsNull(c.getId(), currentUserId);
        return new ConversationDto(
                c.getId(),
                other,
                last != null ? last.getBody() : null,
                last != null ? last.getCreatedAt() : c.getCreatedAt(),
                unreadCount > 0,
                unreadCount);
    }

    private void ensureNotBlocked(UUID a, UUID b) {
        if (blockRepository.existsBetween(a, b)) {
            throw new AppException("You cannot message this user", HttpStatus.FORBIDDEN);
        }
    }

    private User other(Conversation c, UUID currentUserId) {
        return c.getUserA().getId().equals(currentUserId) ? c.getUserB() : c.getUserA();
    }
}
