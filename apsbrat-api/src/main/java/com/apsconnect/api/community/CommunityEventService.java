package com.apsconnect.api.community;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.media.ImageUploadService;
import com.apsconnect.api.notification.NotificationRef;
import com.apsconnect.api.notification.NotificationService;
import com.apsconnect.api.notification.NotificationType;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Reunions and meetups. The community owner or staff create, edit and cancel
 * them; members RSVP. People who RSVP'd hear about time/venue changes and
 * cancellations.
 */
@Service
@RequiredArgsConstructor
public class CommunityEventService {

    /** Past events shown on a community page. */
    // ponytail: no paging for past events; add a cursor if communities pile up more than this.
    private static final int PAST_LIMIT = 30;
    private static final int UPCOMING_LIMIT = 50;
    private static final long MAX_EVENT_DAYS = 30;
    private static final DateTimeFormatter WHEN = DateTimeFormatter.ofPattern("d MMM, h:mm a", Locale.ENGLISH);

    private final CommunityEventRepository eventRepository;
    private final EventRsvpRepository rsvpRepository;
    private final CommunityRepository communityRepository;
    private final CommunityService communityService;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final NotificationService notificationService;
    private final ImageUploadService imageUploadService;
    private final PostRepository postRepository;
    private final com.apsconnect.api.safety.UserBlockRepository blockRepository;

    /** canCreate: I own this community or I'm staff. */
    public record EventList(List<EventDto> events, boolean canCreate) {
    }

    @Transactional(readOnly = true)
    public EventList list(UUID userId, UUID communityId, boolean past) {
        communityService.requireReadable(userId, communityId);
        LocalDateTime now = LocalDateTime.now();
        List<CommunityEvent> events = past
                ? eventRepository.findPast(communityId, now, PageRequest.of(0, PAST_LIMIT))
                : eventRepository.findUpcoming(communityId, now, PageRequest.of(0, UPCOMING_LIMIT));
        return new EventList(toDtos(events, userId), canManage(userId, communityId));
    }

    @Transactional(readOnly = true)
    public EventDto get(UUID userId, UUID eventId) {
        return toDtos(List.of(readableEvent(userId, eventId)), userId).get(0);
    }

    @Transactional
    public EventDto create(UUID userId, UUID communityId, SaveEventRequest request) {
        communityService.requireReadable(userId, communityId);
        requireManager(userId, communityId);
        CommunityEvent event = new CommunityEvent();
        event.setCommunityId(communityId);
        event.setOrganizerId(userId);
        apply(event, request, userId);
        return toDtos(List.of(eventRepository.save(event)), userId).get(0);
    }

    /** Edit. A new time or venue is announced to everyone who RSVP'd. */
    @Transactional
    public EventDto update(UUID userId, UUID eventId, SaveEventRequest request) {
        CommunityEvent event = readableEvent(userId, eventId);
        requireManager(userId, event.getCommunityId());
        if (event.isCancelled()) {
            throw new AppException("This event was cancelled", HttpStatus.BAD_REQUEST);
        }
        LocalDateTime oldStart = event.getStartsAt();
        LocalDateTime oldEnd = event.getEndsAt();
        String oldVenue = event.getVenue();
        apply(event, request, userId);

        if (!event.getStartsAt().equals(oldStart) || !Objects.equals(event.getEndsAt(), oldEnd)
                || !event.getVenue().equals(oldVenue)) {
            notifyRsvps(event, userId, "Event updated: " + event.getTitle(),
                    "Now " + WHEN.format(event.getStartsAt()) + " · " + event.getVenue());
        }
        return toDtos(List.of(event), userId).get(0);
    }

    @Transactional
    public EventDto cancel(UUID userId, UUID eventId) {
        CommunityEvent event = readableEvent(userId, eventId);
        requireManager(userId, event.getCommunityId());
        if (!event.isCancelled()) {
            event.setCancelled(true);
            notifyRsvps(event, userId, "Event cancelled", event.getTitle() + " has been cancelled");
        }
        return toDtos(List.of(event), userId).get(0);
    }

    /** status null = clear my answer. RSVP is for members, and not for cancelled events. */
    @Transactional
    public EventDto rsvp(UUID userId, UUID eventId, EventRsvp.Status status) {
        CommunityEvent event = readableEvent(userId, eventId);
        communityService.requireMember(userId, event.getCommunityId());
        EventRsvp.Key key = new EventRsvp.Key(eventId, userId);
        if (status == null) {
            rsvpRepository.findById(key).ifPresent(rsvpRepository::delete);
        } else {
            if (event.isCancelled()) {
                throw new AppException("This event was cancelled", HttpStatus.BAD_REQUEST);
            }
            if (event.getEndsAt().isBefore(LocalDateTime.now())) {
                throw new AppException("This event is over", HttpStatus.BAD_REQUEST);
            }
            EventRsvp row = rsvpRepository.findById(key).orElseGet(() -> {
                EventRsvp r = new EventRsvp();
                r.setEventId(eventId);
                r.setUserId(userId);
                return r;
            });
            row.setStatus(status);
            rsvpRepository.save(row);
        }
        return toDtos(List.of(event), userId).get(0);
    }

    /** Who's going, then who's interested, in the order they answered. */
    @Transactional(readOnly = true)
    public Map<String, List<PersonDto>> attendees(UUID userId, UUID eventId) {
        readableEvent(userId, eventId);
        java.util.Set<UUID> blocked = new java.util.HashSet<>(blockRepository.findBlockedIdsInvolving(userId));
        List<EventRsvp> rows = rsvpRepository.findByEventIdOrderByCreatedAtAsc(eventId).stream()
                .filter(r -> !blocked.contains(r.getUserId()))
                .toList();
        Map<UUID, PersonDto> people = personService.toPeople(
                        userRepository.findAllById(rows.stream().map(EventRsvp::getUserId).toList()), userId)
                .stream().collect(Collectors.toMap(PersonDto::id, Function.identity()));
        Map<String, List<PersonDto>> out = new HashMap<>();
        for (EventRsvp.Status s : EventRsvp.Status.values()) {
            out.put(s.name(), rows.stream()
                    .filter(r -> r.getStatus() == s && people.containsKey(r.getUserId()))
                    .map(r -> people.get(r.getUserId()))
                    .toList());
        }
        return out;
    }

    /** For tagging a post: the event must be in that community and already started. */
    @Transactional(readOnly = true)
    public CommunityEvent requireTaggable(UUID eventId, UUID communityId) {
        CommunityEvent event = eventRepository.findById(eventId)
                .filter(e -> e.getCommunityId().equals(communityId))
                .orElseThrow(CommunityEventService::notFound);
        if (event.isCancelled() || event.getStartsAt().isAfter(LocalDateTime.now())) {
            throw new AppException("You can share photos once the event has started", HttpStatus.BAD_REQUEST);
        }
        return event;
    }

    @Transactional(readOnly = true)
    public CommunityEvent readableEvent(UUID userId, UUID eventId) {
        CommunityEvent event = eventRepository.findById(eventId).orElseThrow(CommunityEventService::notFound);
        communityService.requireReadable(userId, event.getCommunityId());
        return event;
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private void apply(CommunityEvent event, SaveEventRequest request, UUID userId) {
        if (request.title().trim().length() < 3) {
            throw new AppException("Give it a title of at least 3 characters", HttpStatus.BAD_REQUEST);
        }
        LocalDateTime now = LocalDateTime.now();
        if (!request.endsAt().isAfter(request.startsAt())) {
            throw new AppException("The event must end after it starts", HttpStatus.BAD_REQUEST);
        }
        // A new or changed end time must be in the future (other edits to an old event are fine).
        boolean endChanged = !request.endsAt().equals(event.getEndsAt());
        if (endChanged && !request.endsAt().isAfter(now)) {
            throw new AppException("This event would already be over. Pick a later end time", HttpStatus.BAD_REQUEST);
        }
        if (request.startsAt().isAfter(now.plusYears(3))) {
            throw new AppException("Events can be planned up to 3 years ahead", HttpStatus.BAD_REQUEST);
        }
        if (Duration.between(request.startsAt(), request.endsAt()).toDays() > MAX_EVENT_DAYS) {
            throw new AppException("An event can last at most " + MAX_EVENT_DAYS + " days", HttpStatus.BAD_REQUEST);
        }
        event.setTitle(request.title().trim());
        event.setDescription(request.description() == null || request.description().isBlank()
                ? null : request.description().trim());
        event.setVenue(request.venue().trim());
        event.setStartsAt(request.startsAt());
        event.setEndsAt(request.endsAt());
        event.setCoverUrl(Objects.equals(request.coverUrl(), event.getCoverUrl())
                ? event.getCoverUrl()
                : imageUploadService.requireOwnUpload(userId, request.coverUrl()));
    }

    private boolean canManage(UUID userId, UUID communityId) {
        return communityService.ownedCommunityIds(userId).contains(communityId) || communityService.isStaff(userId);
    }

    private void requireManager(UUID userId, UUID communityId) {
        if (!canManage(userId, communityId)) {
            throw new AppException("Only the community owner can manage events", HttpStatus.FORBIDDEN);
        }
    }

    private void notifyRsvps(CommunityEvent event, UUID actorId, String title, String body) {
        List<UUID> recipients = rsvpRepository.findByEventIdOrderByCreatedAtAsc(event.getId()).stream()
                .map(EventRsvp::getUserId)
                .filter(id -> !id.equals(actorId))
                .toList();
        notificationService.createAll(recipients, NotificationType.GENERAL, title, body,
                userRepository.getReferenceById(actorId), NotificationRef.EVENT, event.getId());
    }

    private List<EventDto> toDtos(List<CommunityEvent> events, UUID viewerId) {
        if (events.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = events.stream().map(CommunityEvent::getId).toList();
        Map<UUID, Map<EventRsvp.Status, Long>> counts = new HashMap<>();
        for (Object[] row : rsvpRepository.countByEvent(ids)) {
            counts.computeIfAbsent((UUID) row[0], k -> new HashMap<>())
                    .put((EventRsvp.Status) row[1], (Long) row[2]);
        }
        Map<UUID, EventRsvp.Status> mine = rsvpRepository.findByUserIdAndEventIdIn(viewerId, ids).stream()
                .collect(Collectors.toMap(EventRsvp::getEventId, EventRsvp::getStatus));
        Map<UUID, PersonDto> organizers = personService.toPeople(userRepository.findAllById(
                        events.stream().map(CommunityEvent::getOrganizerId).distinct().toList()), viewerId)
                .stream().collect(Collectors.toMap(PersonDto::id, Function.identity()));
        Map<UUID, String> communityNames = communityRepository
                .findAllById(events.stream().map(CommunityEvent::getCommunityId).distinct().toList()).stream()
                .collect(Collectors.toMap(Community::getId, Community::getName));
        Map<UUID, Boolean> manage = new HashMap<>();
        Map<UUID, Long> photos = postRepository.countByEvent(ids, ContentStatus.ACTIVE).stream()
                .collect(Collectors.toMap(r -> (UUID) r[0], r -> (Long) r[1]));

        return events.stream()
                .map(e -> {
                    Map<EventRsvp.Status, Long> c = counts.getOrDefault(e.getId(), Map.of());
                    return new EventDto(e.getId(), e.getCommunityId(), communityNames.get(e.getCommunityId()),
                            e.getTitle(), e.getDescription(), e.getVenue(), e.getStartsAt(), e.getEndsAt(),
                            e.getCoverUrl(), e.isCancelled(), organizers.get(e.getOrganizerId()),
                            c.getOrDefault(EventRsvp.Status.GOING, 0L),
                            c.getOrDefault(EventRsvp.Status.INTERESTED, 0L),
                            photos.getOrDefault(e.getId(), 0L),
                            mine.get(e.getId()),
                            manage.computeIfAbsent(e.getCommunityId(), cid -> canManage(viewerId, cid)));
                })
                .toList();
    }

    private static AppException notFound() {
        return new AppException("Event not found", HttpStatus.NOT_FOUND);
    }
}
