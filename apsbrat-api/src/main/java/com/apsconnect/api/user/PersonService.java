package com.apsconnect.api.user;

import com.apsconnect.api.connection.Connection;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.connection.ConnectionStatus;
import com.apsconnect.api.user.history.UserSchoolHistory;
import com.apsconnect.api.user.history.UserSchoolHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PersonService {

    private final UserSchoolHistoryRepository historyRepository;
    private final ConnectionRepository connectionRepository;

    /** Single person — one history query. Prefer toPeople(...) for lists. */
    @Transactional(readOnly = true)
    public PersonDto toPerson(User user) {
        return build(user, historyRepository.findAllByUser_Id(user.getId()), 0, "NONE");
    }

    /**
     * Batch builder: ONE query loads every person's school history (school eager-joined),
     * eliminating the per-person N+1 that hit feed / connections / search / chat / avatars.
     */
    @Transactional(readOnly = true)
    public List<PersonDto> toPeople(List<User> users) {
        return toPeople(users, null);
    }

    /**
     * Same as {@link #toPeople(List)} but also fills each person's number of
     * mutual connections with {@code viewerId} (one extra query for the whole list).
     */
    @Transactional(readOnly = true)
    public List<PersonDto> toPeople(List<User> users, UUID viewerId) {
        if (users == null || users.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = users.stream().map(User::getId).toList();
        Map<UUID, List<UserSchoolHistory>> byUser = historyRepository.findAllWithSchoolByUserIds(ids).stream()
                .collect(Collectors.groupingBy(h -> h.getUser().getId()));
        Map<UUID, Integer> mutual = mutualCounts(viewerId, ids);
        Map<UUID, String> relation = relations(viewerId, ids);
        return users.stream()
                .map(u -> build(u, byUser.getOrDefault(u.getId(), List.of()),
                        mutual.getOrDefault(u.getId(), 0), relation.getOrDefault(u.getId(), "NONE")))
                .toList();
    }

    /** Viewer's relation to each id, from one query over the live connection rows. */
    @Transactional(readOnly = true)
    public Map<UUID, String> relations(UUID viewerId, List<UUID> ids) {
        if (viewerId == null || ids.isEmpty()) {
            return Map.of();
        }
        Map<UUID, String> out = new HashMap<>();
        for (Connection c : connectionRepository.findLiveWithIds(viewerId, ids)) {
            boolean iAsked = c.getRequester().getId().equals(viewerId);
            UUID other = iAsked ? c.getAddressee().getId() : c.getRequester().getId();
            String rel = c.getStatus() == ConnectionStatus.ACCEPTED ? "CONNECTED"
                    : (iAsked ? "PENDING_OUT" : "PENDING_IN");
            out.put(other, rel);
        }
        return out;
    }

    /** Mutual-connection count between the viewer and each id; empty when there is no viewer. */
    @Transactional(readOnly = true)
    public Map<UUID, Integer> mutualCounts(UUID viewerId, List<UUID> ids) {
        if (viewerId == null || ids.isEmpty()) {
            return Map.of();
        }
        Map<UUID, Integer> counts = new HashMap<>();
        for (Object[] row : connectionRepository.countMutual(viewerId, ids)) {
            counts.put((UUID) row[0], ((Number) row[1]).intValue());
        }
        return counts;
    }

    private PersonDto build(User user, List<UserSchoolHistory> history, int mutualCount, String relation) {
        UserSchoolHistory primary = history.stream()
                .filter(UserSchoolHistory::isPrimary)
                .findFirst()
                .orElse(history.stream()
                        .max(Comparator.comparingInt(h -> h.getBatchEnd()))
                        .orElse(null));

        String schoolName = primary != null && primary.getSchool() != null ? primary.getSchool().getName() : "";
        String detail = "";
        List<String> tags = new ArrayList<>();
        if (primary != null) {
            // "12D · Class 2020" — class number + section letter, or just the class.
            String classLabel = primary.getClassTo() + (primary.getSection() == null ? "" : primary.getSection());
            detail = classLabel + " · Class " + primary.getBatchEnd();
            String shortSchool = schoolName.replaceFirst("(?i)^APS\\s+", "");
            tags.add(classLabel + " " + shortSchool);
            if (primary.getStream() != null) {
                tags.add(primary.getStream().label());
            }
        }
        tags.add(user.getCurrentStatus() == UserStatus.ALUMNI ? "Alumni" : "Student");

        return new PersonDto(
                user.getId(),
                user.getUsername(),
                initials(user.getFullName()),
                user.getFullName(),
                schoolName,
                detail,
                user.getCity(),
                user.getProfession(),
                user.getCurrentStatus(),
                user.getProfilePicUrl(),
                false,
                tags,
                mutualCount,
                relation
        );
    }

    private String initials(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            return "?";
        }
        String[] parts = fullName.trim().split("\\s+");
        StringBuilder sb = new StringBuilder();
        sb.append(Character.toUpperCase(parts[0].charAt(0)));
        if (parts.length > 1) {
            sb.append(Character.toUpperCase(parts[parts.length - 1].charAt(0)));
        }
        return sb.toString();
    }
}
