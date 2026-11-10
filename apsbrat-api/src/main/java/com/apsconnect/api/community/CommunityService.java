package com.apsconnect.api.community;

import com.apsconnect.api.career.NameKeys;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.security.SecurityUtils;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.UserRole;
import com.apsconnect.api.user.history.UserSchoolHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CommunityService {

    private final CommunityRepository communityRepository;
    private final CommunityMemberRepository memberRepository;
    private final JoinRequestRepository joinRequestRepository;
    private final UserSchoolHistoryRepository schoolHistoryRepository;
    private final UserRepository userRepository;
    private final PersonService personService;

    private static final int MAX_CREATED_PER_USER = 5;

    /** Communities I'm in (schools first), and my schools' communities I haven't joined. */
    @Transactional(readOnly = true)
    public MyCommunitiesDto mine(UUID userId) {
        Map<UUID, MemberRole> myRoles = memberRepository.findByUserId(userId).stream()
                .collect(Collectors.toMap(CommunityMember::getCommunityId, CommunityMember::getRole));

        List<CommunityDto> joined = communityRepository.findAllById(myRoles.keySet()).stream()
                .sorted(Comparator.comparing((Community c) -> c.getType() != CommunityType.SCHOOL)
                        .thenComparing(Community::getName))
                .map(c -> CommunityDto.of(c, myRoles.get(c.getId()), false))
                .toList();

        List<CommunityDto> suggested = communityRepository
                .findBySchoolIdIn(schoolHistoryRepository.findSchoolIdsByUserId(userId)).stream()
                .filter(c -> !myRoles.containsKey(c.getId()))
                .sorted(Comparator.comparing(Community::getName))
                .map(c -> CommunityDto.of(c, null, false))
                .toList();

        return new MyCommunitiesDto(joined, suggested);
    }

    @Transactional(readOnly = true)
    public CommunityDto get(UUID userId, UUID communityId) {
        Community community = visibleCommunity(userId, communityId);
        CommunityMember.Key key = new CommunityMember.Key(communityId, userId);
        MemberRole myRole = memberRepository.findById(key).map(CommunityMember::getRole).orElse(null);
        boolean requested = myRole == null && joinRequestRepository.existsById(key);
        return CommunityDto.of(community, myRole, requested);
    }

    /**
     * SCHOOL (only that school's students) and OPEN: member at once.
     * PRIVATE: a join request for the owner to approve.
     * Joining twice changes nothing.
     */
    @Transactional
    public CommunityDto join(UUID userId, UUID communityId) {
        Community community = visibleCommunity(userId, communityId);
        CommunityMember.Key key = new CommunityMember.Key(communityId, userId);

        if (!memberRepository.existsById(key)) {
            if (community.getVisibility() == CommunityVisibility.PRIVATE) {
                if (!joinRequestRepository.existsById(key)) {
                    JoinRequest request = new JoinRequest();
                    request.setCommunityId(communityId);
                    request.setUserId(userId);
                    joinRequestRepository.save(request);
                }
            } else {
                addMember(communityId, userId, MemberRole.MEMBER);
            }
        }
        return get(userId, communityId);
    }
    @Transactional
    public void leave(UUID userId, UUID communityId) {
        CommunityMember member = memberRepository.findById(new CommunityMember.Key(communityId, userId))
                .orElseThrow(() -> new AppException("You're not in this community", HttpStatus.NOT_FOUND));
        if (member.getRole() == MemberRole.OWNER) {
            throw new AppException("Owners can't leave their own community", HttpStatus.BAD_REQUEST);
        }
        removeMember(member);
    }

    /**
     * Called whenever someone's school history is saved: they leave the
     * communities of schools they no longer list (they're no longer eligible).
     */
    @Transactional
    public void dropSchoolsNoLongerListed(UUID userId) {
        Set<UUID> mySchools = new HashSet<>(schoolHistoryRepository.findSchoolIdsByUserId(userId));
        Map<UUID, CommunityMember> myMemberships = memberRepository.findByUserId(userId).stream()
                .collect(Collectors.toMap(CommunityMember::getCommunityId, Function.identity()));

        communityRepository.findAllById(myMemberships.keySet()).stream()
                .filter(c -> c.getType() == CommunityType.SCHOOL && !mySchools.contains(c.getSchoolId()))
                .forEach(c -> removeMember(myMemberships.get(c.getId())));
    }

    // ── Interest communities ────────────────────────────────────────────────

    /** Anyone can create up to 5. The creator becomes the OWNER and first member. */
    @Transactional
    public CommunityDto create(UUID userId, CreateCommunityRequest request) {
        String name = request.name().trim();
        String nameKey = NameKeys.of(name);
        if (nameKey.length() < 3) {
            throw new AppException("Use at least 3 letters or numbers in the name", HttpStatus.BAD_REQUEST);
        }
        if (communityRepository.countByCreatedByAndType(userId, CommunityType.INTEREST) >= MAX_CREATED_PER_USER) {
            throw new AppException("You can create up to " + MAX_CREATED_PER_USER + " communities",
                    HttpStatus.BAD_REQUEST);
        }
        if (communityRepository.existsByTypeAndNameKey(CommunityType.INTEREST, nameKey)) {
            throw new AppException("A community with this name already exists", HttpStatus.CONFLICT);
        }

        Community community = new Community();
        community.setType(CommunityType.INTEREST);
        community.setName(name);
        community.setNameKey(nameKey);
        String description = request.description();
        community.setDescription(description == null || description.isBlank() ? null : description.trim());
        community.setVisibility(request.visibility());
        community.setCreatedBy(userId);
        community = communityRepository.save(community);

        addMember(community.getId(), userId, MemberRole.OWNER);
        return get(userId, community.getId());
    }

    /** Interest communities by name (all of them when q is blank), with my state on each. */
    @Transactional(readOnly = true)
    public List<CommunityDto> discover(UUID userId, String q) {
        Map<UUID, MemberRole> myRoles = memberRepository.findByUserId(userId).stream()
                .collect(Collectors.toMap(CommunityMember::getCommunityId, CommunityMember::getRole));
        Set<UUID> myRequests = joinRequestRepository.findByUserId(userId).stream()
                .map(JoinRequest::getCommunityId)
                .collect(Collectors.toSet());

        return communityRepository
                .findTop20ByTypeAndNameKeyContainingOrderByMemberCountDescNameAsc(CommunityType.INTEREST, NameKeys.of(q))
                .stream()
                .map(c -> CommunityDto.of(c, myRoles.get(c.getId()), myRequests.contains(c.getId())))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<JoinRequestDto> requests(UUID ownerId, UUID communityId) {
        requireOwner(ownerId, communityId);
        List<JoinRequest> requests = joinRequestRepository.findByCommunityIdOrderByCreatedAtAsc(communityId);
        // All requesters' cards in one go (no query per person).
        Map<UUID, PersonDto> people = personService
                .toPeople(userRepository.findAllById(requests.stream().map(JoinRequest::getUserId).toList()))
                .stream()
                .collect(Collectors.toMap(PersonDto::id, Function.identity()));
        return requests.stream()
                .filter(r -> people.containsKey(r.getUserId()))
                .map(r -> new JoinRequestDto(people.get(r.getUserId()), r.getCreatedAt()))
                .toList();
    }

    @Transactional
    public void approve(UUID ownerId, UUID communityId, UUID userId) {
        requireOwner(ownerId, communityId);
        JoinRequest request = joinRequestRepository.findById(new CommunityMember.Key(communityId, userId))
                .orElseThrow(() -> new AppException("Request not found", HttpStatus.NOT_FOUND));
        joinRequestRepository.delete(request);
        addMember(communityId, userId, MemberRole.MEMBER);
    }

    @Transactional
    public void reject(UUID ownerId, UUID communityId, UUID userId) {
        requireOwner(ownerId, communityId);
        JoinRequest request = joinRequestRepository.findById(new CommunityMember.Key(communityId, userId))
                .orElseThrow(() -> new AppException("Request not found", HttpStatus.NOT_FOUND));
        joinRequestRepository.delete(request);
    }

    @Transactional
    public void removeMemberAsOwner(UUID ownerId, UUID communityId, UUID userId) {
        requireOwner(ownerId, communityId);
        if (ownerId.equals(userId)) {
            throw new AppException("You can't remove yourself; delete the community instead", HttpStatus.BAD_REQUEST);
        }
        CommunityMember member = memberRepository.findById(new CommunityMember.Key(communityId, userId))
                .orElseThrow(() -> new AppException("Not a member", HttpStatus.NOT_FOUND));
        removeMember(member);
    }

    /** Deletes the community; its members, requests and posts go with it (ON DELETE CASCADE). */
    @Transactional
    public void delete(UUID ownerId, UUID communityId) {
        communityRepository.delete(requireOwner(ownerId, communityId));
    }

    // ── Access rules for posts (see the table in docs/communities-course 1.5) ──

    /**
     * Whose posts I may read. SCHOOL: that school's students. OPEN: everyone.
     * PRIVATE: members only (the community itself is public, so 403 not 404).
     */
    @Transactional(readOnly = true)
    public Community requireReadable(UUID userId, UUID communityId) {
        Community community = visibleCommunity(userId, communityId);
        if (community.getVisibility() == CommunityVisibility.PRIVATE
                && !memberRepository.existsById(new CommunityMember.Key(communityId, userId))) {
            throw new AppException("Join this community to see its posts", HttpStatus.FORBIDDEN);
        }
        return community;
    }

    /** Posting, liking and commenting are for members. */
    @Transactional(readOnly = true)
    public Community requireMember(UUID userId, UUID communityId) {
        Community community = requireReadable(userId, communityId);
        if (!memberRepository.existsById(new CommunityMember.Key(communityId, userId))) {
            throw new AppException("Join this community first", HttpStatus.FORBIDDEN);
        }
        return community;
    }

    /** The communities where I may delete anyone's posts: the ones I own. */
    @Transactional(readOnly = true)
    public Set<UUID> ownedCommunityIds(UUID userId) {
        return new HashSet<>(memberRepository.findCommunityIdsByUserIdAndRole(userId, MemberRole.OWNER));
    }

    /** App-wide ADMIN or MODERATOR: may delete anything anywhere. */
    @Transactional(readOnly = true)
    public boolean isStaff(UUID userId) {
        // The signed-in user's role is already in their token: no lookup for the common case.
        if (userId.equals(SecurityUtils.currentUserIdOrNull())) {
            return SecurityContextHolder.getContext().getAuthentication().getAuthorities().stream()
                    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_MODERATOR"));
        }
        return userRepository.findById(userId)
                .map(u -> u.getRole() == UserRole.ADMIN || u.getRole() == UserRole.MODERATOR)
                .orElse(false);
    }

    /** Every community I'm in (for the Home feed). */
    @Transactional(readOnly = true)
    public List<UUID> myCommunityIds(UUID userId) {
        return memberRepository.findCommunityIdsByUserId(userId);
    }

    private Community requireOwner(UUID userId, UUID communityId) {
        Community community = visibleCommunity(userId, communityId);
        boolean owner = memberRepository.findById(new CommunityMember.Key(communityId, userId))
                .map(m -> m.getRole() == MemberRole.OWNER)
                .orElse(false);
        if (!owner) {
            throw new AppException("Only the owner can do this", HttpStatus.FORBIDDEN);
        }
        return community;
    }

    private void addMember(UUID communityId, UUID userId, MemberRole role) {
        CommunityMember member = new CommunityMember();
        member.setCommunityId(communityId);
        member.setUserId(userId);
        member.setRole(role);
        memberRepository.save(member);
        communityRepository.addToMemberCount(communityId, 1);
    }

    private void removeMember(CommunityMember member) {
        memberRepository.delete(member);
        communityRepository.addToMemberCount(member.getCommunityId(), -1);
    }

    /**
     * A SCHOOL community exists only for that school's students; anyone else
     * gets 404, the same answer as for an id that doesn't exist.
     */
    private Community visibleCommunity(UUID userId, UUID communityId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(CommunityService::notFound);
        if (community.getType() == CommunityType.SCHOOL
                && !schoolHistoryRepository.existsByUser_IdAndSchool_Id(userId, community.getSchoolId())) {
            throw notFound();
        }
        return community;
    }

    private static AppException notFound() {
        return new AppException("Community not found", HttpStatus.NOT_FOUND);
    }
}