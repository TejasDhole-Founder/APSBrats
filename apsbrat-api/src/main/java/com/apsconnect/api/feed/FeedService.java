package com.apsconnect.api.feed;

import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FeedService {

    private final FeedEventRepository feedEventRepository;
    private final UserRepository userRepository;
    private final PersonService personService;

    @Transactional(readOnly = true)
    public List<FeedEventDto> activity(int limit) {
        List<FeedEvent> events = feedEventRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(0, limit));
        // Batch-build the actor PersonDtos once, then look them up per event.
        List<User> actors = events.stream().map(FeedEvent::getActor).toList();
        Map<UUID, PersonDto> byId = personService.toPeople(actors).stream()
                .collect(Collectors.toMap(PersonDto::id, Function.identity(), (a, b) -> a));
        return events.stream()
                .map(e -> new FeedEventDto(
                        e.getId(),
                        byId.get(e.getActor().getId()),
                        e.getType(),
                        typeLabel(e.getType()),
                        e.getTitle(),
                        e.getBody(),
                        e.getMeta(),
                        e.getCreatedAt()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<PersonDto> recentJoins(UUID currentUserId) {
        List<User> users = userRepository.findTop12ByOrderByCreatedAtDesc().stream()
                .filter(u -> !u.getId().equals(currentUserId))
                .toList();
        return personService.toPeople(users);
    }

    @Transactional(readOnly = true)
    public BatchmateBannerDto banner(UUID currentUserId) {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        List<User> today = userRepository.findByCreatedAtAfterOrderByCreatedAtDesc(startOfDay).stream()
                .filter(u -> !u.getId().equals(currentUserId))
                .toList();
        List<String> names = today.stream()
                .map(u -> u.getFullName() == null ? "" : u.getFullName().trim().split("\\s+")[0])
                .limit(3)
                .toList();
        String message = today.isEmpty()
                ? "No new batchmates yet today."
                : today.size() + " new batchmate" + (today.size() == 1 ? "" : "s") + " joined today.";
        return new BatchmateBannerDto(today.size(), names, message);
    }

    private String typeLabel(FeedEventType type) {
        return switch (type) {
            case JOIN -> "New join";
            case CONNECTED -> "Connected";
            case GENERAL -> "Update";
        };
    }
}
