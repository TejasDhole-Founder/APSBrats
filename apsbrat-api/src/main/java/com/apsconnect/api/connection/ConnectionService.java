package com.apsconnect.api.connection;

import com.apsconnect.api.common.exception.AppException;
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

        // One query covers both directions instead of two point lookups.
        if (!connectionRepository.findBetween(currentUserId, targetUserId).isEmpty()) {
            throw new AppException("Connection already exists", HttpStatus.CONFLICT);
        }

        Connection connection = new Connection();
        connection.setRequester(requester);
        connection.setAddressee(addressee);
        connection.setStatus(ConnectionStatus.PENDING);
        connection.setCreatedAt(LocalDateTime.now());
        connectionRepository.save(connection);

        notificationService.create(targetUserId, NotificationType.CONNECTION_REQUEST,
                requester.getFullName() + " wants to connect",
                "You have a new connection request on APS Brat.");
    }

    @Transactional
    public void acceptConnection(UUID currentUserId, UUID otherUserId) {
        Connection connection = connectionRepository
                .findByRequester_IdAndAddressee_Id(otherUserId, currentUserId)
                .orElseThrow(() -> new AppException("No pending request from this user", HttpStatus.NOT_FOUND));
        connection.setStatus(ConnectionStatus.ACCEPTED);
        connectionRepository.save(connection);

        notificationService.create(otherUserId, NotificationType.CONNECTION_ACCEPTED,
                connection.getAddressee().getFullName() + " accepted your request",
                "You can now message each other on APS Brat.");
    }

    @Transactional(readOnly = true)
    public List<PersonDto> listBatchmates(UUID currentUserId) {
        List<User> others = connectionRepository.findAcceptedForUser(currentUserId).stream()
                .map(c -> other(c, currentUserId))
                .toList();
        return personService.toPeople(others);
    }

    @Transactional(readOnly = true)
    public List<PersonDto> listPending(UUID currentUserId) {
        List<User> requesters = connectionRepository.findPendingIncoming(currentUserId).stream()
                .map(Connection::getRequester)
                .toList();
        return personService.toPeople(requesters);
    }

    @Transactional(readOnly = true)
    public String statusWith(UUID currentUserId, UUID otherUserId) {
        for (Connection c : connectionRepository.findBetween(currentUserId, otherUserId)) {
            boolean iRequested = c.getRequester().getId().equals(currentUserId);
            if (c.getStatus() == ConnectionStatus.ACCEPTED) {
                return "CONNECTED";
            }
            return iRequested ? "PENDING_OUT" : "PENDING_IN";
        }
        return "NONE";
    }

    @Transactional(readOnly = true)
    public long acceptedCount(UUID userId) {
        return connectionRepository.countAcceptedForUser(userId);
    }

    private User other(Connection c, UUID currentUserId) {
        return c.getRequester().getId().equals(currentUserId) ? c.getAddressee() : c.getRequester();
    }
}
