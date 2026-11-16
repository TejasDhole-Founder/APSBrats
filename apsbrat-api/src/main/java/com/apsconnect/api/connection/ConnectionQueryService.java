package com.apsconnect.api.connection;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.util.CursorSupport;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Reads: connection lists, status with one person, mutual connections and relationship history. */
@Service
@RequiredArgsConstructor
public class ConnectionQueryService {

    private static final int HISTORY_LIMIT = 200;

    private final ConnectionRepository connectionRepository;
    private final ConnectionEventRepository eventRepository;
    private final UserRepository userRepository;
    private final PersonService personService;

    @Transactional(readOnly = true)
    public List<PersonDto> listBatchmates(UUID currentUserId) {
        List<User> others = connectionRepository.findAcceptedForUser(currentUserId).stream()
                .map(c -> other(c, currentUserId))
                .filter(u -> u.getDeletedAt() == null)
                .sorted(Comparator.comparing(User::getFullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
        return personService.toPeople(others, currentUserId);
    }

    /** My connections, A to Z, one page at a time. */
    @Transactional(readOnly = true)
    public CursorPage<PersonDto> pageConnections(UUID currentUserId, String cursor, int limit) {
        int size = CursorSupport.clampLimit(limit);
        KeysetCursor after = KeysetCursor.decode(cursor);
        List<Object[]> rows = connectionRepository.findFriendsPage(
                currentUserId, after.key(), after.id(), size + 1);
        return toPage(rows, size, currentUserId);
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

    /** Requests waiting for me, newest first, one page at a time. */
    @Transactional(readOnly = true)
    public CursorPage<PersonDto> pageReceived(UUID currentUserId, String cursor, int limit) {
        int size = CursorSupport.clampLimit(limit);
        KeysetCursor after = requestCursor(cursor);
        return toRequestPage(connectionRepository.findReceivedPage(
                currentUserId, after.key(), after.id(), size + 1), size, currentUserId);
    }

    /** Requests I sent that nobody has answered, newest first, one page at a time. */
    @Transactional(readOnly = true)
    public CursorPage<PersonDto> pageSent(UUID currentUserId, String cursor, int limit) {
        int size = CursorSupport.clampLimit(limit);
        KeysetCursor after = requestCursor(cursor);
        return toRequestPage(connectionRepository.findSentPage(
                currentUserId, after.key(), after.id(), size + 1), size, currentUserId);
    }

    /** People connected to both me and the other user, ordered by name (everyone, no page). */
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

    /** How many connections I share with this person; a number only, worked out in SQL. */
    @Transactional(readOnly = true)
    public long mutualCount(UUID currentUserId, UUID otherUserId) {
        return connectionRepository.countMutualBetween(currentUserId, otherUserId);
    }

    /** The shared connections, A to Z, one page at a time. */
    @Transactional(readOnly = true)
    public CursorPage<PersonDto> pageMutual(UUID currentUserId, UUID otherUserId, String cursor, int limit) {
        int size = CursorSupport.clampLimit(limit);
        KeysetCursor after = KeysetCursor.decode(cursor);
        List<Object[]> rows = connectionRepository.findMutualPage(
                currentUserId, otherUserId, after.key(), after.id(), size + 1);
        return toPage(rows, size, currentUserId);
    }

    @Transactional(readOnly = true)
    public String statusWith(UUID currentUserId, UUID otherUserId) {
        Connection c = connectionRepository.findBetween(currentUserId, otherUserId)
                .filter(x -> x.getStatus().isLive())
                .orElse(null);
        if (c == null) {
            return "NONE";
        }
        if (c.getStatus() == ConnectionStatus.ACCEPTED) {
            return "CONNECTED";
        }
        return c.getRequester().getId().equals(currentUserId) ? "PENDING_OUT" : "PENDING_IN";
    }

    /**
     * What happened between me and this person, oldest first (up to {@value #HISTORY_LIMIT}
     * events). Only the two people involved can ask: the pair is always me and the other user.
     */
    @Transactional(readOnly = true)
    public List<ConnectionEventDto> history(UUID currentUserId, UUID otherUserId) {
        Connection connection = connectionRepository.findBetween(currentUserId, otherUserId)
                .orElseThrow(() -> new AppException("No connection with this user", HttpStatus.NOT_FOUND));
        return eventRepository
                .findByConnectionIdOrderByCreatedAtAscIdAsc(connection.getId(), PageRequest.of(0, HISTORY_LIMIT))
                .stream()
                .map(ConnectionEventDto::from)
                .toList();
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private CursorPage<PersonDto> toPage(List<Object[]> rows, int size, UUID viewerId) {
        boolean hasMore = rows.size() > size;
        List<Object[]> page = hasMore ? rows.subList(0, size) : rows;
        List<UUID> ids = page.stream().map(r -> (UUID) r[0]).toList();
        Map<UUID, User> users = userRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        // Keep the SQL order: the page is sorted by (lower name, id).
        List<User> ordered = ids.stream().map(users::get).filter(java.util.Objects::nonNull).toList();
        String next = null;
        if (hasMore) {
            Object[] last = page.get(page.size() - 1);
            next = KeysetCursor.encode((String) last[1], (UUID) last[0]);
        }
        return CursorPage.of(personService.toPeople(ordered, viewerId), next, hasMore);
    }

    /** The cursor of a requests page: the key is the request time, checked here so a bad one is a 400, not a SQL error. */
    private static KeysetCursor requestCursor(String cursor) {
        KeysetCursor after = KeysetCursor.decode(cursor);
        if (after.key() != null) {
            try {
                LocalDateTime.parse(after.key());
            } catch (RuntimeException ex) {
                throw new AppException("Invalid cursor", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
            }
        }
        return after;
    }

    /** Same response as the other pages. Rows: [person id, requested_at, connection id], newest first. */
    private CursorPage<PersonDto> toRequestPage(List<Object[]> rows, int size, UUID viewerId) {
        boolean hasMore = rows.size() > size;
        List<Object[]> page = hasMore ? rows.subList(0, size) : rows;
        List<UUID> ids = page.stream().map(r -> (UUID) r[0]).toList();
        Map<UUID, User> users = userRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<User> ordered = ids.stream().map(users::get).filter(java.util.Objects::nonNull).toList();
        String next = null;
        if (hasMore) {
            Object[] last = page.get(page.size() - 1);
            next = KeysetCursor.encode(toLocalDateTime(last[1]).toString(), (UUID) last[2]);
        }
        return CursorPage.of(personService.toPeople(ordered, viewerId), next, hasMore);
    }

    private static LocalDateTime toLocalDateTime(Object value) {
        if (value instanceof Timestamp t) {
            return t.toLocalDateTime();
        }
        if (value instanceof LocalDateTime t) {
            return t;
        }
        throw new IllegalStateException("Unexpected timestamp type " + value.getClass());
    }

    private static User other(Connection c, UUID currentUserId) {
        return c.getRequester().getId().equals(currentUserId) ? c.getAddressee() : c.getRequester();
    }

    /**
     * Where the last page stopped: the sort key (a lower-cased name, or a request time), then an id.
     * Encoded as URL-safe base64 of "{id}|{key}"; the id is always 36 characters so the key may hold any text.
     */
    private record KeysetCursor(String key, String id) {

        static final KeysetCursor FIRST = new KeysetCursor(null, null);

        static String encode(String key, UUID id) {
            String raw = id + "|" + key;
            return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
        }

        static KeysetCursor decode(String cursor) {
            if (cursor == null || cursor.isBlank()) {
                return FIRST;
            }
            try {
                String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
                if (raw.length() < 37 || raw.charAt(36) != '|') {
                    throw new IllegalArgumentException("bad cursor");
                }
                UUID id = UUID.fromString(raw.substring(0, 36));
                return new KeysetCursor(raw.substring(37), id.toString());
            } catch (RuntimeException ex) {
                throw new AppException("Invalid cursor", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
            }
        }
    }
}
