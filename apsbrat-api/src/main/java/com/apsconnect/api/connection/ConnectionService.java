package com.apsconnect.api.connection;

import com.apsconnect.api.circle.CircleCache;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.notification.NotificationRef;
import com.apsconnect.api.notification.NotificationService;
import com.apsconnect.api.notification.NotificationType;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ConnectionService {

    private final ConnectionRepository connectionRepository;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final NotificationService notificationService;
    private final UserBlockRepository blockRepository;
    private final CircleCache circleCache;

    @Transactional
    public void requestConnection(UUID currentUserId, UUID targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            throw new AppException("Cannot connect with yourself", HttpStatus.BAD_REQUEST);
        }
        User requester = userRepository.findById(currentUserId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        User addressee = userRepository.findById(targetUserId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("Target user not found", HttpStatus.NOT_FOUND));
        if (blockRepository.existsBetween(currentUserId, targetUserId)) {
            throw new AppException("Target user not found", HttpStatus.NOT_FOUND);
        }

        // One row per pair. A live row means "already asked / already friends";
        // a closed row (declined, withdrawn, removed) is reused for the new request.
        Connection connection = connectionRepository.findBetween(currentUserId, targetUserId).stream()
                .findFirst().orElse(null);
        if (connection != null && connection.getStatus().isLive()) {
            throw new AppException("Connection already exists", HttpStatus.CONFLICT);
        }
        if (connection == null) {
            connection = new Connection();
        }
        connection.setRequester(requester);
        connection.setAddressee(addressee);
        connection.setStatus(ConnectionStatus.PENDING);
        connection.setCreatedAt(LocalDateTime.now());
        connection.setAcceptedAt(null);
        connection = connectionRepository.save(connection);

        notificationService.create(targetUserId, NotificationType.CONNECTION_REQUEST,
                requester.getFullName() + " wants to connect",
                "You have a new connection request on APS Brat.",
                requester, NotificationRef.CONNECTION, connection.getId());
        circleCache.evictUser(currentUserId);
        circleCache.evictUser(targetUserId);
    }

    @Transactional
    public void acceptConnection(UUID currentUserId, UUID otherUserId) {
        Connection connection = pendingBetween(currentUserId, otherUserId);
        if (!connection.getAddressee().getId().equals(currentUserId)) {
            throw new AppException("Only the person who received the request can accept it", HttpStatus.FORBIDDEN);
        }
        connection.setStatus(ConnectionStatus.ACCEPTED);
        connection.setAcceptedAt(LocalDateTime.now());
        connectionRepository.save(connection);

        notificationService.create(otherUserId, NotificationType.CONNECTION_ACCEPTED,
                connection.getAddressee().getFullName() + " accepted your request",
                "You can now message each other on APS Brat.",
                connection.getAddressee(), NotificationRef.USER, currentUserId);
        circleCache.evictUser(currentUserId);
        circleCache.evictUser(otherUserId);
    }

    /**
     * Ends whatever is live between me and the other person:
     * a request I received → DECLINED, a request I sent → WITHDRAWN,
     * an accepted connection → REMOVED. Nothing live → 404.
     */
    @Transactional
    public ConnectionStatus endConnection(UUID currentUserId, UUID otherUserId) {
        Connection connection = connectionRepository.findBetween(currentUserId, otherUserId).stream()
                .filter(c -> c.getStatus().isLive())
                .findFirst()
                .orElseThrow(() -> new AppException("No connection with this user", HttpStatus.NOT_FOUND));
        ConnectionStatus next = closedStatus(connection, currentUserId);
        connection.setStatus(next);
        connectionRepository.save(connection);
        circleCache.evictUser(currentUserId);
        circleCache.evictUser(otherUserId);
        return next;
    }

    static ConnectionStatus closedStatus(Connection connection, UUID actor) {
        if (connection.getStatus() == ConnectionStatus.ACCEPTED) {
            return ConnectionStatus.REMOVED;
        }
        boolean actorIsAddressee = connection.getAddressee().getId().equals(actor);
        return actorIsAddressee ? ConnectionStatus.DECLINED : ConnectionStatus.WITHDRAWN;
    }

    @Transactional(readOnly = true)
    public List<PersonDto> listBatchmates(UUID currentUserId) {
        List<User> others = connectionRepository.findAcceptedForUser(currentUserId).stream()
                .map(c -> other(c, currentUserId))
                .filter(u -> u.getDeletedAt() == null)
                .sorted(Comparator.comparing(User::getFullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
        return personService.toPeople(others, currentUserId);
    }

    @Transactional(readOnly = true)
    public List<PersonDto> listPending(UUID currentUserId) {
        List<User> requesters = connectionRepository.findPendingIncoming(currentUserId).stream()
                .map(Connection::getRequester)
                .toList();
        return personService.toPeople(requesters, currentUserId);
    }

    @Transactional(readOnly = true)
    public List<PersonDto> listSent(UUID currentUserId) {
        List<User> addressees = connectionRepository.findPendingSent(currentUserId).stream()
                .map(Connection::getAddressee)
                .toList();
        return personService.toPeople(addressees, currentUserId);
    }

    /** People connected to both me and the other user, ordered by name. */
    @Transactional(readOnly = true)
    public List<PersonDto> listMutual(UUID currentUserId, UUID otherUserId) {
        List<UUID> ids = connectionRepository.findMutualIds(currentUserId, otherUserId);
        if (ids.isEmpty()) {
            return List.of();
        }
        List<User> people = userRepository.findAllById(ids).stream()
                .filter(u -> u.getDeletedAt() == null)
                .sorted(Comparator.comparing(User::getFullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
        return personService.toPeople(people, currentUserId);
    }

    @Transactional(readOnly = true)
    public String statusWith(UUID currentUserId, UUID otherUserId) {
        Connection c = connectionRepository.findBetween(currentUserId, otherUserId).stream()
                .filter(x -> x.getStatus().isLive())
                .findFirst().orElse(null);
        if (c == null) {
            return "NONE";
        }
        if (c.getStatus() == ConnectionStatus.ACCEPTED) {
            return "CONNECTED";
        }
        return c.getRequester().getId().equals(currentUserId) ? "PENDING_OUT" : "PENDING_IN";
    }

    private Connection pendingBetween(UUID a, UUID b) {
        return connectionRepository.findBetween(a, b).stream()
                .filter(c -> c.getStatus() == ConnectionStatus.PENDING)
                .findFirst()
                .orElseThrow(() -> new AppException("No pending request from this user", HttpStatus.NOT_FOUND));
    }

    private User other(Connection c, UUID currentUserId) {
        return c.getRequester().getId().equals(currentUserId) ? c.getAddressee() : c.getRequester();
    }
}
