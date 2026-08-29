package com.apsconnect.api.search;

import com.apsconnect.api.community.Community;
import com.apsconnect.api.community.CommunityMemberRepository;
import com.apsconnect.api.community.CommunityRepository;
import com.apsconnect.api.community.DiscoverCommunityDto;
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
    private final CommunityRepository communityRepository;
    private final CommunityMemberRepository communityMemberRepository;
    private final PersonService personService;
    private final UserBlockRepository blockRepository;
    private final UserSettingsService settingsService;

    @Transactional(readOnly = true)
    public SearchResultDto search(UUID currentUserId, String query) {
        String term = query == null ? "" : query.trim();
        if (term.isEmpty()) {
            return new SearchResultDto(List.of(), List.of());
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

        List<DiscoverCommunityDto> communities = communityRepository.findByNameContainingIgnoreCase(term).stream()
                .limit(MAX_RESULTS)
                .map(this::toDiscover)
                .toList();

        return new SearchResultDto(people, communities);
    }

    private DiscoverCommunityDto toDiscover(Community c) {
        long count = c.getMemberCountOverride() != null
                ? c.getMemberCountOverride()
                : communityMemberRepository.countByCommunity_Id(c.getId());
        return new DiscoverCommunityDto(c.getId(), c.getName(), count + " members", c.getSubtitle());
    }
}
