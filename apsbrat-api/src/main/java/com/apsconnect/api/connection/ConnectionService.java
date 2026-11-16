package com.apsconnect.api.connection;

import com.apsconnect.api.circle.CircleCache;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.notification.NotificationRef;
import com.apsconnect.api.notification.NotificationService;
import com.apsconnect.api.notification.NotificationType;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

/**
 * Every change to a relationship: request, accept, decline / withdraw / remove, and the
 * removal a block causes. Lists, status and mutual connections live in {@link ConnectionQueryService}.
 *
 * <p>Each change first takes the pair's lock ({@link ConnectionRepository#lock}), reads the
 * single row for the pair, checks who may do what, writes the new state, records a history
 * event, and notifies the other person, all in one transaction. The lock makes two people
 * acting on each other at once (or two taps of the same button) run one after the other, even
 * across servers; the unique key on the pair is the safety net underneath.
 */
@Service
@RequiredArgsConstructor
public class ConnectionService {

    private final ConnectionRepository connectionRepository;
    private final ConnectionEventRepository eventRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final UserBlockRepository blockRepository;
    private final CircleCache circleCache;

    /**
     * Ask to connect. Returns PENDING, or ACCEPTED when the other person had already asked me
     * (then their request is simply accepted: still one row).
     */
    @Transactional
    public ConnectionStatus requestConnection(UUID currentUserId, UUID targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            throw new AppException("Cannot connect with yourself", HttpStatus.BAD_REQUEST);
        }
        UserPair pair = UserPair.of(currentUserId, targetUserId);
        connectionRepository.lock(pair);

        User requester = userRepository.findById(currentUserId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        User addressee = userRepository.findById(targetUserId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("Target user not found", HttpStatus.NOT_FOUND));
        // Checked after taking the lock: a block that committed while we waited is seen here.
        if (blockRepository.existsBetween(currentUserId, targetUserId)) {
            throw new AppException("Target user not found", HttpStatus.NOT_FOUND);
        }

        Connection connection = connectionRepository.findByPair(pair.low(), pair.high()).orElse(null);
        LocalDateTime now = LocalDateTime.now();

        if (connection == null) {
            connection = connectionRepository.saveAndFlush(Connection.newRequest(requester, addressee));
            record(connection, currentUserId, ConnectionEventType.REQUESTED, now, null);
            notifyRequest(requester, addressee, connection);
            evict(currentUserId, targetUserId);
            return ConnectionStatus.PENDING;
        }

        switch (connection.getStatus()) {
            case ACCEPTED -> throw new AppException("Connection already exists", HttpStatus.CONFLICT);
            case PENDING -> {
                if (connection.getRequester().getId().equals(currentUserId)) {
                    throw new AppException("Connection already exists", HttpStatus.CONFLICT);
                }
                // They already asked me and I am asking them: that is a yes.
                record(connection, currentUserId, ConnectionEventType.REQUESTED, now,
                        Map.of("reason", "REVERSE_REQUEST"));
                accept(connection, currentUserId, now.plusNanos(1_000));
                return ConnectionStatus.ACCEPTED;
            }
            default -> {
                // Declined, withdrawn or removed before: reuse the row for the new request.
                // created_at stays; requested_at is the new request.
                connection.setRequester(requester);
                connection.setAddressee(addressee);
                connection.setStatus(ConnectionStatus.PENDING);
                connection.setRequestedAt(now);
                connection.setAcceptedAt(null);
                connectionRepository.saveAndFlush(connection);
                record(connection, currentUserId, ConnectionEventType.REQUESTED, now, null);
                notifyRequest(requester, addressee, connection);
                evict(currentUserId, targetUserId);
                return ConnectionStatus.PENDING;
            }
        }
    }

    /** Only the person who received the request can accept it. Accepting twice changes nothing. */
    @Transactional
    public void acceptConnection(UUID currentUserId, UUID otherUserId) {
        UserPair pair = UserPair.of(currentUserId, otherUserId);
        connectionRepository.lock(pair);
        Connection connection = connectionRepository.findByPair(pair.low(), pair.high())
                .orElseThrow(() -> new AppException("No pending request from this user", HttpStatus.NOT_FOUND));
        if (!connection.getAddressee().getId().equals(currentUserId)) {
            throw new AppException("Only the person who received the request can accept it", HttpStatus.FORBIDDEN);
        }
        if (connection.getStatus() == ConnectionStatus.ACCEPTED) {
            return;
        }
        if (connection.getStatus() != ConnectionStatus.PENDING) {
            throw new AppException("No pending request from this user", HttpStatus.NOT_FOUND);
        }
        accept(connection, currentUserId, LocalDateTime.now());
    }

    /**
     * Ends whatever is live between me and the other person:
     * a request I received → DECLINED, a request I sent → WITHDRAWN,
     * an accepted connection → REMOVED. Nothing live → 404.
     */
    @Transactional
    public ConnectionStatus endConnection(UUID currentUserId, UUID otherUserId) {
        UserPair pair = UserPair.of(currentUserId, otherUserId);
        connectionRepository.lock(pair);
        Connection connection = connectionRepository.findByPair(pair.low(), pair.high())
                .filter(c -> c.getStatus().isLive())
                .orElseThrow(() -> new AppException("No connection with this user", HttpStatus.NOT_FOUND));
        ConnectionStatus next = closedStatus(connection, currentUserId);
        close(connection, next, currentUserId, null);
        evict(currentUserId, otherUserId);
        return next;
    }

    /**
     * Called when [blockerId] blocks [blockedId]: whatever was live between them ends (REMOVED, as
     * before) and the history says so. The reason is kept in the event only, so the blocked person
     * cannot tell a block from an ordinary removal.
     */
    @Transactional
    public void endForBlock(UUID blockerId, UUID blockedId) {
        UserPair pair = UserPair.of(blockerId, blockedId);
        connectionRepository.lock(pair);
        connectionRepository.findByPair(pair.low(), pair.high())
                .filter(c -> c.getStatus().isLive())
                .ifPresent(c -> {
                    close(c, ConnectionStatus.REMOVED, blockerId, Map.of("reason", "BLOCK"));
                    evict(blockerId, blockedId);
                });
    }

    static ConnectionStatus closedStatus(Connection connection, UUID actor) {
        if (connection.getStatus() == ConnectionStatus.ACCEPTED) {
            return ConnectionStatus.REMOVED;
        }
        boolean actorIsAddressee = connection.getAddressee().getId().equals(actor);
        return actorIsAddressee ? ConnectionStatus.DECLINED : ConnectionStatus.WITHDRAWN;
    }

    // ── helpers ──────────────────────────────────────────────────────────

    /** Marks a pending row accepted by its addressee, records it, and tells the person who asked. */
    private void accept(Connection connection, UUID actorId, LocalDateTime at) {
        User addressee = connection.getAddressee();
        UUID requesterId = connection.getRequester().getId();
        connection.setStatus(ConnectionStatus.ACCEPTED);
        connection.setAcceptedAt(at);
        connectionRepository.saveAndFlush(connection);
        record(connection, actorId, ConnectionEventType.ACCEPTED, at, null);

        notificationService.create(requesterId, NotificationType.CONNECTION_ACCEPTED,
                addressee.getFullName() + " accepted your request",
                "You can now message each other on APS Brat.",
                addressee, NotificationRef.USER, addressee.getId());
        evict(requesterId, addressee.getId());
    }

    private void close(Connection connection, ConnectionStatus next, UUID actorId, Map<String, String> metadata) {
        connection.setStatus(next);
        connectionRepository.saveAndFlush(connection);
        record(connection, actorId, ConnectionEventType.valueOf(next.name()), LocalDateTime.now(), metadata);
    }

    private void notifyRequest(User requester, User addressee, Connection connection) {
        notificationService.create(addressee.getId(), NotificationType.CONNECTION_REQUEST,
                requester.getFullName() + " wants to connect",
                "You have a new connection request on APS Brat.",
                requester, NotificationRef.CONNECTION, connection.getId());
    }

    private void record(Connection connection, UUID actorId, ConnectionEventType type,
                        LocalDateTime at, Map<String, String> metadata) {
        eventRepository.save(ConnectionEvent.of(connection.getId(), actorId, type, at, metadata));
    }

    private void evict(UUID a, UUID b) {
        circleCache.evictUser(a);
        circleCache.evictUser(b);
    }
}
