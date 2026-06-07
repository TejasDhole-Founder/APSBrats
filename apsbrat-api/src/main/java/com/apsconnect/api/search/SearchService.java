package com.apsconnect.api.search;

import com.apsconnect.api.community.Community;
import com.apsconnect.api.community.CommunityMemberRepository;
import com.apsconnect.api.community.CommunityRepository;
import com.apsconnect.api.community.DiscoverCommunityDto;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SearchService {

    private final UserRepository userRepository;
    private final CommunityRepository communityRepository;
    private final CommunityMemberRepository communityMemberRepository;
    private final PersonService personService;

    @Transactional(readOnly = true)
    public SearchResultDto search(UUID currentUserId, String query) {
        String term = query == null ? "" : query.trim();
        if (term.isEmpty()) {
            return new SearchResultDto(List.of(), List.of());
        }

        List<User> users = userRepository.search(term).stream()
                .filter(u -> !u.getId().equals(currentUserId))
                .toList();
        List<PersonDto> people = personService.toPeople(users);

        List<DiscoverCommunityDto> communities = communityRepository.findByNameContainingIgnoreCase(term).stream()
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
