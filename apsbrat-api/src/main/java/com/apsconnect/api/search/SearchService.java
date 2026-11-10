package com.apsconnect.api.search;

import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.settings.UserSettingsDto;
import com.apsconnect.api.user.settings.UserSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SearchService {

    private static final int MAX_RESULTS = 50;

    private final UserRepository userRepository;
    private final PersonService personService;
    private final UserBlockRepository blockRepository;
    private final UserSettingsService settingsService;

    @Transactional(readOnly = true)
    public SearchResultDto search(UUID currentUserId, String query) {
        String term = query == null ? "" : query.trim();
        if (term.isEmpty()) {
            return new SearchResultDto(List.of());
        }

        Set<UUID> excluded = new HashSet<>(blockRepository.findBlockedIdsInvolving(currentUserId));
        excluded.add(currentUserId);

        List<User> candidates = userRepository.search(term).stream()
                .filter(u -> u.getDeletedAt() == null)
                .filter(u -> !excluded.contains(u.getId()))
                .toList();

        Map<UUID, UserSettingsDto> settings = settingsService.forUsers(
                candidates.stream().map(User::getId).toList());

        List<User> users = candidates.stream()
                .filter(u -> settings.getOrDefault(u.getId(), UserSettingsDto.defaults()).discoverable())
                .limit(MAX_RESULTS)
                .toList();

        List<PersonDto> people = personService.toPeople(users);

        return new SearchResultDto(people);
    }
}
