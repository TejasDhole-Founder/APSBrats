package com.apsconnect.api.community;

import com.apsconnect.api.chat.SendChatMessageRequest;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.util.CursorSupport;
import com.apsconnect.api.media.ImageUploadService;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.PresenceService;
import com.apsconnect.api.user.settings.UserSettingsService;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Each community's group chat: members read and write; author, owner and staff delete. */
@Service
@RequiredArgsConstructor
public class CommunityChatService {

    /** Live pushes land here on each member's device. */
    public static final String QUEUE = "/queue/community";
    private static final int MAX_LENGTH = 2000;
    private static final int MAX_MESSAGES_PER_HOUR = 120;
    /** Stands in for "nobody" so NOT IN (...) is never given an empty list. */
    private static final UUID NOBODY = new UUID(0, 0);

    private final CommunityMessageRepository messageRepository;
    private final CommunityMemberRepository memberRepository;
    private final CommunityService communityService;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final UserBlockRepository blockRepository;
    private final ImageUploadService imageUploadService;
    private final SimpMessagingTemplate messagingTemplate;
    private final SimpUserRegistry userRegistry;
    private final StringRedisTemplate redis;
    private final UserSettingsService settingsService;

    /** onlineCount is null when I hide my own activity (then I see nobody's). */
    public record Summary(CommunityMessageDto lastMessage, long unreadCount, boolean canModerate, Long onlineCount) {
    }

    /** Oldest first within the page, like a chat screen; the cursor walks back in time. */
    @Transactional(readOnly = true)
    public CursorPage<CommunityMessageDto> messages(UUID userId, UUID communityId, String cursor, int limit) {
        communityService.requireMember(userId, communityId);
        int size = CursorSupport.clampLimit(limit);
        LocalDateTime before = CursorSupport.decode(cursor);
        List<CommunityMessage> rows = messageRepository.findPage(communityId, ContentStatus.ACTIVE,
                before == null ? LocalDateTime.now().plusMinutes(1) : before,
                hiddenSenders(userId), PageRequest.of(0, size + 1));

        boolean hasMore = rows.size() > size;
        if (hasMore) {
            rows = rows.subList(0, size);
        }
        String next = hasMore ? CursorSupport.encode(rows.get(rows.size() - 1).getCreatedAt()) : null;
        List<CommunityMessageDto> items = new ArrayList<>(toDtos(rows, false));
        Collections.reverse(items);
        return CursorPage.of(items, next, hasMore);
    }

    /** For the community page: the latest message, my unread count, and whether I can moderate. */
    @Transactional(readOnly = true)
    public Summary summary(UUID userId, UUID communityId) {
        communityService.requireMember(userId, communityId);
        CommunityMember me = memberRepository.findById(new CommunityMember.Key(communityId, userId)).orElseThrow();
        Set<UUID> hidden = hiddenSenders(userId);
        List<CommunityMessage> last = messageRepository.findPage(communityId, ContentStatus.ACTIVE,
                LocalDateTime.now().plusMinutes(1), hidden, PageRequest.of(0, 1));
        LocalDateTime since = me.getChatReadAt() != null ? me.getChatReadAt() : me.getJoinedAt();
        long unread = messageRepository.countUnread(communityId, ContentStatus.ACTIVE, userId, hidden, since);
        Long online = settingsService.get(userId).showActivity()
                ? memberRepository.countActiveSince(communityId,
                        LocalDateTime.now().minus(PresenceService.ONLINE_WINDOW))
                : null;
        return new Summary(last.isEmpty() ? null : toDtos(last, false).get(0), unread,
                canModerate(userId, communityId), online);
    }

    @Transactional
    public CommunityMessageDto send(UUID userId, UUID communityId, SendChatMessageRequest request) {
        communityService.requireMember(userId, communityId);
        rateLimit(userId);

        String body = request.body() == null ? "" : request.body().trim();
        if (body.length() > MAX_LENGTH) {
            throw new AppException("Keep messages under " + MAX_LENGTH + " characters", HttpStatus.BAD_REQUEST);
        }
        String photo = imageUploadService.requireOwnUpload(userId, request.imageUrl());
        if (body.isEmpty() && photo == null) {
            throw new AppException("Write a message or add a photo", HttpStatus.BAD_REQUEST);
        }

        CommunityMessage message = new CommunityMessage();
        message.setCommunityId(communityId);
        message.setSenderId(userId);
        message.setBody(body);
        message.setImageUrl(photo);
        message = messageRepository.save(message);
        // My own message is read by me.
        memberRepository.findById(new CommunityMember.Key(communityId, userId))
                .ifPresent(m -> m.setChatReadAt(LocalDateTime.now()));

        CommunityMessageDto dto = toDtos(List.of(message), false).get(0);
        pushAfterCommit(message, dto);
        return dto;
    }

    @Transactional
    public void markRead(UUID userId, UUID communityId) {
        communityService.requireMember(userId, communityId);
        memberRepository.findById(new CommunityMember.Key(communityId, userId))
                .ifPresent(m -> m.setChatReadAt(LocalDateTime.now()));
    }

    /** Soft delete by the author, the community owner or staff; open chats drop it at once. */
    @Transactional
    public void delete(UUID userId, UUID messageId) {
        CommunityMessage message = messageRepository.findById(messageId)
                .filter(m -> m.getStatus() == ContentStatus.ACTIVE)
                .orElseThrow(CommunityChatService::notFound);
        if (!message.getSenderId().equals(userId) && !canModerate(userId, message.getCommunityId())) {
            throw new AppException("You can't delete this message", HttpStatus.FORBIDDEN);
        }
        setStatus(message, ContentStatus.REMOVED);
    }

    // ── Moderation hooks (reports and staff) ───────────────────────────────

    /** A report must point at a message the reporter can see: a member of that community. */
    @Transactional(readOnly = true)
    public void requireReportable(UUID userId, UUID messageId) {
        CommunityMessage message = messageRepository.findById(messageId)
                .filter(m -> m.getStatus() == ContentStatus.ACTIVE)
                .orElseThrow(() -> new AppException("Reported item not found", HttpStatus.NOT_FOUND));
        communityService.requireMember(userId, message.getCommunityId());
        if (message.getSenderId().equals(userId)) {
            throw new AppException("You can't report your own message", HttpStatus.BAD_REQUEST);
        }
    }

    @Transactional
    public void hide(UUID messageId) {
        messageRepository.findById(messageId)
                .filter(m -> m.getStatus() == ContentStatus.ACTIVE)
                .ifPresent(m -> setStatus(m, ContentStatus.HIDDEN));
    }

    @Transactional
    public void restore(UUID messageId) {
        CommunityMessage message = messageRepository.findById(messageId).orElseThrow(CommunityChatService::notFound);
        message.setStatus(ContentStatus.ACTIVE);
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private void setStatus(CommunityMessage message, ContentStatus status) {
        message.setStatus(status);
        pushAfterCommit(message, toDtos(List.of(message), true).get(0));
    }

    private boolean canModerate(UUID userId, UUID communityId) {
        return communityService.ownedCommunityIds(userId).contains(communityId) || communityService.isStaff(userId);
    }

    /**
     * After the save commits, sends the message to every member who is connected
     * right now, skipping anyone blocked with the sender (either way).
     */
    // ponytail: scans connected users per message; switch to a broker relay/topics if concurrent users reach thousands.
    private void pushAfterCommit(CommunityMessage message, CommunityMessageDto dto) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                Set<UUID> online = userRegistry.getUsers().stream()
                        .map(u -> UUID.fromString(u.getName()))
                        .collect(Collectors.toSet());
                if (online.isEmpty()) {
                    return;
                }
                Set<UUID> skip = new HashSet<>(blockRepository.findBlockedIdsInvolving(message.getSenderId()));
                for (UUID memberId : memberRepository.findUserIdsIn(message.getCommunityId(), online)) {
                    if (!skip.contains(memberId)) {
                        messagingTemplate.convertAndSendToUser(memberId.toString(), QUEUE, dto);
                    }
                }
            }
        });
    }

    private List<CommunityMessageDto> toDtos(List<CommunityMessage> messages, boolean removed) {
        if (messages.isEmpty()) {
            return List.of();
        }
        Map<UUID, PersonDto> senders = personService.toPeople(userRepository.findAllById(
                        messages.stream().map(CommunityMessage::getSenderId).distinct().toList())).stream()
                .collect(Collectors.toMap(PersonDto::id, Function.identity()));
        return messages.stream()
                .filter(m -> senders.containsKey(m.getSenderId()))
                .map(m -> new CommunityMessageDto(m.getId(), m.getCommunityId(), senders.get(m.getSenderId()),
                        m.getBody(), m.getImageUrl(), removed, m.getCreatedAt()))
                .toList();
    }

    /** People whose messages I never see: those I blocked and those who blocked me. */
    private Set<UUID> hiddenSenders(UUID userId) {
        Set<UUID> ids = new HashSet<>(blockRepository.findBlockedIdsInvolving(userId));
        ids.add(NOBODY);
        return ids;
    }

    private void rateLimit(UUID userId) {
        String key = "ratelimit:community-chat:" + userId;
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redis.expire(key, Duration.ofHours(1));
        }
        if (count != null && count > MAX_MESSAGES_PER_HOUR) {
            throw new AppException("You're sending a lot. Try again in a little while.",
                    HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
    }

    private static AppException notFound() {
        return new AppException("Message not found", HttpStatus.NOT_FOUND);
    }
}
