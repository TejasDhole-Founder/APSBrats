package com.apsconnect.api.chat;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.util.CursorSupport;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final com.apsconnect.api.media.ImageUploadService imageUploadService;
    private final ConversationRepository conversationRepository;
    private final ChatMessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final SimpMessagingTemplate messagingTemplate;
    private final com.apsconnect.api.safety.UserBlockRepository blockRepository;

    @Transactional
    public ConversationDto openWith(UUID myId, UUID otherId) {
        if (myId.equals(otherId)) {
            throw new AppException("You can't message yourself", HttpStatus.BAD_REQUEST);
        }
        User other = userRepository.findById(otherId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        // Blocked either way, or a deleted account: they don't exist as far as I'm concerned.
        if (other.getDeletedAt() != null || blockRepository.existsBetween(myId, otherId)) {
            throw new AppException("User not found", HttpStatus.NOT_FOUND);
        }

        UUID smaller = myId.compareTo(otherId) < 0 ? myId : otherId;
        UUID larger = myId.compareTo(otherId) < 0 ? otherId : myId;

        Conversation conversation = conversationRepository.findByUserA_IdAndUserB_Id(smaller, larger)
                .orElseGet(() -> createConversation(smaller, larger));

        return toConversationDto(conversation, myId);
    }

    private Conversation createConversation(UUID smaller, UUID larger) {
        try {
            User userA = userRepository.getReferenceById(smaller);
            User userB = userRepository.getReferenceById(larger);
            Conversation conversation = new Conversation();
            conversation.setUserA(userA);
            conversation.setUserB(userB);
            return conversationRepository.save(conversation);
        } catch (DataIntegrityViolationException raceLostToAnotherRequest) {
            return conversationRepository.findByUserA_IdAndUserB_Id(smaller, larger)
                    .orElseThrow(() -> raceLostToAnotherRequest);
        }
    }

    private ConversationDto toConversationDto(Conversation conversation, UUID myId) {
        PersonDto person = personService.toPerson(otherUser(conversation, myId));
        var lastMessage = messageRepository.findTopByConversation_IdOrderByCreatedAtDesc(conversation.getId())
                .orElse(null);
        long unreadCount = messageRepository.countByConversation_IdAndSender_IdNotAndReadAtIsNull(
                conversation.getId(), myId);
        return toConversationDto(conversation, person, lastMessage, unreadCount);
    }

    private static ConversationDto toConversationDto(Conversation conversation, PersonDto person,
                                                     ChatMessage lastMessage, long unreadCount) {
        String preview = lastMessage == null ? null
                : (lastMessage.getBody().isEmpty() && lastMessage.getImageUrl() != null ? "📷 Photo" : lastMessage.getBody());
        LocalDateTime time = lastMessage != null ? lastMessage.getCreatedAt() : conversation.getCreatedAt();
        return new ConversationDto(conversation.getId(), person, preview, time, unreadCount > 0, unreadCount);
    }

    private static User otherUser(Conversation conversation, UUID myId) {
        return conversation.getUserA().getId().equals(myId) ? conversation.getUserB() : conversation.getUserA();
    }

    private static final int MAX_LEN_CONNECTED = 4000;
    private static final int MAX_LEN_UNCONNECTED = 300;

    /** A fixed number of queries however many conversations there are (was 4 per conversation). */
    @Transactional(readOnly = true)
    public List<ConversationDto> listConversations(UUID myId) {
        Set<UUID> blocked = new HashSet<>(blockRepository.findBlockedIdsInvolving(myId));
        List<Conversation> all = conversationRepository.findActiveFor(myId).stream()
                .filter(c -> !blocked.contains(otherUserId(c, myId)))
                .toList();
        if (all.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = all.stream().map(Conversation::getId).toList();
        Map<UUID, ChatMessage> latest = new HashMap<>();
        for (ChatMessage m : messageRepository.findLatestIn(ids)) {
            latest.put(m.getConversation().getId(), m);
        }
        Map<UUID, Long> unread = new HashMap<>();
        for (Object[] row : messageRepository.countUnreadIn(ids, myId)) {
            unread.put((UUID) row[0], (Long) row[1]);
        }
        List<PersonDto> people = personService.toPeople(all.stream().map(c -> otherUser(c, myId)).toList(), myId);

        List<ConversationDto> result = new ArrayList<>(all.size());
        for (int i = 0; i < all.size(); i++) {
            Conversation c = all.get(i);
            result.add(toConversationDto(c, people.get(i), latest.get(c.getId()), unread.getOrDefault(c.getId(), 0L)));
        }
        return result;
    }

    @Transactional(readOnly = true)
    public CursorPage<ChatMessageDto> messages(UUID myId, UUID conversationId, String cursor, int limit) {
        requireParticipant(conversationId, myId);

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

        List<ChatMessageDto> items = new ArrayList<>(rows.stream()
                .map(m -> toMessageDto(m, myId))
                .toList());
        Collections.reverse(items);
        return CursorPage.of(items, nextCursor, hasMore);
    }

    @Transactional
    public ChatMessageDto sendMessage(UUID myId, UUID conversationId, String body, String imageUrl) {
        Conversation conversation = requireParticipant(conversationId, myId);
        UUID otherId = otherUserId(conversation, myId);
        if (blockRepository.existsBetween(myId, otherId)) {
            throw new AppException("Conversation not found", HttpStatus.NOT_FOUND);
        }

        String relation = personService.relations(myId, List.of(otherId)).getOrDefault(otherId, "NONE");
        int maxLen = relation.equals("CONNECTED") ? MAX_LEN_CONNECTED : MAX_LEN_UNCONNECTED;

        String trimmed = body == null ? "" : body.trim();
        String photo = imageUploadService.requireOwnUpload(myId, imageUrl);
        if (trimmed.isEmpty() && photo == null) {
            throw new AppException("Write a message or add a photo", HttpStatus.BAD_REQUEST);
        }
        // Photos only between connected people: a stranger can't open with an image.
        if (photo != null && !relation.equals("CONNECTED")) {
            throw new AppException("You can send photos once you're connected", HttpStatus.FORBIDDEN);
        }
        if (trimmed.length() > maxLen) {
            throw new AppException("Message too long for an unconnected contact (max " + maxLen + " chars)",
                    HttpStatus.BAD_REQUEST);
        }

        if (!relation.equals("CONNECTED")) {
            boolean iAlreadySent = messageRepository.existsByConversation_IdAndSender_Id(conversationId, myId);
            boolean theyReplied = messageRepository.existsByConversation_IdAndSender_Id(conversationId, otherId);
            if (iAlreadySent && !theyReplied) {
                throw new AppException(
                        "Wait for a reply, or connect, before sending another message",
                        HttpStatus.FORBIDDEN);
            }
        }

        User sender = userRepository.getReferenceById(myId);
        ChatMessage message = new ChatMessage();
        message.setConversation(conversation);
        message.setSender(sender);
        message.setBody(trimmed);
        message.setImageUrl(photo);
        message = messageRepository.save(message);

        conversation.setLastMessageAt(message.getCreatedAt());
        ChatMessage saved = message;
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                ChatMessageDto pushed = toMessageDto(saved, otherId);
                messagingTemplate.convertAndSendToUser(otherId.toString(), "/queue/messages", pushed);
            }
        });
        return toMessageDto(message, myId);
    }

    @Transactional
    public void markRead(UUID myId, UUID conversationId) {
        requireParticipant(conversationId, myId);
        messageRepository.markRead(conversationId, myId, LocalDateTime.now());
    }

    private Conversation requireParticipant(UUID conversationId, UUID myId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
        boolean isParticipant = conversation.getUserA().getId().equals(myId)
                || conversation.getUserB().getId().equals(myId);
        if (!isParticipant) {
            throw new AppException("Conversation not found", HttpStatus.NOT_FOUND);
        }
        return conversation;
    }

    private UUID otherUserId(Conversation conversation, UUID myId) {
        return conversation.getUserA().getId().equals(myId)
                ? conversation.getUserB().getId()
                : conversation.getUserA().getId();
    }

    private ChatMessageDto toMessageDto(ChatMessage message, UUID myId) {
        return new ChatMessageDto(
                message.getId(),
                message.getConversation().getId(),
                message.getSender().getId(),
                message.getBody(),
                message.getImageUrl(),
                message.getSender().getId().equals(myId),
                message.getCreatedAt());
    }
}