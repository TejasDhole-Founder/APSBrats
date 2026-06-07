package com.apsconnect.api.user;

import com.apsconnect.api.user.history.UserSchoolHistory;
import com.apsconnect.api.user.history.UserSchoolHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PersonService {

    private final UserSchoolHistoryRepository historyRepository;

    /** Single person — one history query. Prefer toPeople(...) for lists. */
    @Transactional(readOnly = true)
    public PersonDto toPerson(User user) {
        return build(user, historyRepository.findAllByUser_Id(user.getId()));
    }

    /**
     * Batch builder: ONE query loads every person's school history (school eager-joined),
     * eliminating the per-person N+1 that hit feed / connections / search / chat / avatars.
     */
    @Transactional(readOnly = true)
    public List<PersonDto> toPeople(List<User> users) {
        if (users == null || users.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = users.stream().map(User::getId).toList();
        Map<UUID, List<UserSchoolHistory>> byUser = historyRepository.findAllWithSchoolByUserIds(ids).stream()
                .collect(Collectors.groupingBy(h -> h.getUser().getId()));
        return users.stream()
                .map(u -> build(u, byUser.getOrDefault(u.getId(), List.of())))
                .toList();
    }

    private PersonDto build(User user, List<UserSchoolHistory> history) {
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
            detail = primary.getSection() + " · Class " + primary.getBatchEnd();
            String shortSchool = schoolName.replaceFirst("(?i)^APS\\s+", "");
            tags.add(primary.getSection() + " " + shortSchool);
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
                tags
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
