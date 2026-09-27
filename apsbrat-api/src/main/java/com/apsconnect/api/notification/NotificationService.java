package com.apsconnect.api.notification;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.connection.Connection;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.connection.ConnectionStatus;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class NotificationService {

    public static final int PAGE_SIZE = 30;

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final ConnectionRepository connectionRepository;

    /** System notice with no actor or reference. */
    @Transactional
    public void create(UUID userId, NotificationType type, String title, String body) {
        create(userId, type, title, body, null, null, null);
    }

    /** Notice about a person, pointing at something the app can open or act on. */
    @Transactional
    public void create(UUID userId, NotificationType type, String title, String body,
                       User actor, NotificationRef refType, UUID refId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        Notification n = new Notification();
        n.setUser(user);
        n.setActor(actor);
        n.setType(type);
        n.setTitle(title);
        n.setBody(body);
        n.setRefType(refType);
        n.setRefId(refId);
        n.setRead(false);
        n.setCreatedAt(LocalDateTime.now());
        notificationRepository.save(n);
    }

    /**
     * Newest first, one page. Request notifications are marked actionable only
     * while the connection they point at is still PENDING, so Home, the bell sheet
     * and the profile button never disagree.
     */
    @Transactional(readOnly = true)
    public List<NotificationDto> list(UUID userId, int page) {
        List<Notification> rows = notificationRepository
                .findAllByUser_IdOrderByCreatedAtDesc(userId, PageRequest.of(Math.max(page, 0), PAGE_SIZE));

        Set<UUID> connectionIds = rows.stream()
                .filter(n -> n.getRefType() == NotificationRef.CONNECTION && n.getRefId() != null)
                .map(Notification::getRefId)
                .collect(Collectors.toSet());
        Set<UUID> stillPending = connectionIds.isEmpty() ? Set.of()
                : connectionRepository.findAllById(connectionIds).stream()
                        .filter(c -> c.getStatus() == ConnectionStatus.PENDING)
                        .map(Connection::getId)
                        .collect(Collectors.toSet());

        return rows.stream()
                .map(n -> NotificationDto.from(n,
                        n.getType() == NotificationType.CONNECTION_REQUEST
                                && n.getRefId() != null
                                && stillPending.contains(n.getRefId())))
                .toList();
    }

    @Transactional(readOnly = true)
    public long unreadCount(UUID userId) {
        return notificationRepository.countByUser_IdAndReadFalse(userId);
    }

    @Transactional
    public void markRead(UUID userId, UUID notificationId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new AppException("Notification not found", HttpStatus.NOT_FOUND));
        if (!n.getUser().getId().equals(userId)) {
            throw new AppException("Not your notification", HttpStatus.FORBIDDEN);
        }
        n.setRead(true);
        notificationRepository.save(n);
    }

    @Transactional
    public void markAllRead(UUID userId) {
        notificationRepository.markAllRead(userId);
    }
}
