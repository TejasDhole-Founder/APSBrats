package com.apsconnect.api.community;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.realtime.RealtimeService;
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

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CommunityService {

    private final CommunityRepository communityRepository;
    private final CommunityMemberRepository memberRepository;
    private final CommunityMessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final RealtimeService realtimeService;

    @Transactional(readOnly = true)
    public List<CommunityDto> myCommunities(UUID currentUserId) {
        return memberRepository.findAllByUser_IdOrderByJoinedAtDesc(currentUserId).stream()
                .map(m -> toDto(m.getCommunity(), m))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<DiscoverCommunityDto> discover(UUID currentUserId) {
        return communityRepository.findByTypeIn(List.of(CommunityType.ALL_YEARS, CommunityType.GLOBAL)).stream()
                .filter(c -> !memberRepository.existsByCommunity_IdAndUser_Id(c.getId(), currentUserId))
                .map(c -> new DiscoverCommunityDto(
                        c.getId(),
                        c.getName(),
                        memberCountText(c) + " members",
                        c.getSubtitle()))
                .toList();
    }

    @Transactional(readOnly = true)
    public CommunityDto get(UUID currentUserId, UUID communityId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new AppException("Community not found", HttpStatus.NOT_FOUND));
        CommunityMember member = memberRepository.findByCommunity_IdAndUser_Id(communityId, currentUserId).orElse(null);
        return toDto(community, member);
    }

    @Transactional(readOnly = true)
    public CursorPage<CommunityMessageDto> messages(UUID currentUserId, UUID communityId, String cursor, int limit) {
        communityRepository.findById(communityId)
                .orElseThrow(() -> new AppException("Community not found", HttpStatus.NOT_FOUND));
        if (!memberRepository.existsByCommunity_IdAndUser_Id(communityId, currentUserId)) {
            throw new AppException("Not a member of this community", HttpStatus.FORBIDDEN);
        }
        int pageSize = CursorSupport.clampLimit(limit);
        var pageable = PageRequest.of(0, pageSize + 1);
        LocalDateTime before = CursorSupport.decode(cursor);

        List<CommunityMessage> rows = before == null
                ? messageRepository.findByCommunity_IdOrderByCreatedAtDesc(communityId, pageable)
                : messageRepository.findByCommunity_IdAndCreatedAtLessThanOrderByCreatedAtDesc(
                        communityId, before, pageable);

        boolean hasMore = rows.size() > pageSize;
        if (hasMore) {
            rows = rows.subList(0, pageSize);
        }
        String nextCursor = hasMore && !rows.isEmpty()
                ? CursorSupport.encode(rows.get(rows.size() - 1).getCreatedAt())
                : null;

        List<User> senders = rows.stream().map(CommunityMessage::getSender).toList();
        Map<UUID, PersonDto> byId = personService.toPeople(senders).stream()
                .collect(Collectors.toMap(PersonDto::id, Function.identity(), (a, b) -> a));

        List<CommunityMessageDto> items = new ArrayList<>(rows.stream()
                .map(m -> new CommunityMessageDto(
                        m.getId(),
                        m.getSender().getId(),
                        byId.get(m.getSender().getId()),
                        m.getBody(),
                        m.getSender().getId().equals(currentUserId),
                        m.getCreatedAt()))
                .toList());
        java.util.Collections.reverse(items);
        return CursorPage.of(items, nextCursor, hasMore);
    }

    @Transactional
    public CommunityMessageDto sendMessage(UUID currentUserId, UUID communityId, String body) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new AppException("Community not found", HttpStatus.NOT_FOUND));
        User sender = userRepository.findById(currentUserId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        if (!memberRepository.existsByCommunity_IdAndUser_Id(communityId, currentUserId)) {
            throw new AppException("Not a member of this community", HttpStatus.FORBIDDEN);
        }
        CommunityMessage message = new CommunityMessage();
        message.setCommunity(community);
        message.setSender(sender);
        message.setBody(body.trim());
        message.setCreatedAt(LocalDateTime.now());
        message = messageRepository.save(message);

        CommunityMessageDto broadcast = new CommunityMessageDto(message.getId(), sender.getId(),
                personService.toPerson(sender), message.getBody(), false, message.getCreatedAt());
        realtimeService.publishCommunityMessage(communityId, broadcast);

        return new CommunityMessageDto(message.getId(), sender.getId(), personService.toPerson(sender),
                message.getBody(), true, message.getCreatedAt());
    }

    @Transactional
    public void join(UUID currentUserId, UUID communityId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new AppException("Community not found", HttpStatus.NOT_FOUND));
        if (memberRepository.existsByCommunity_IdAndUser_Id(communityId, currentUserId)) {
            return;
        }
        User user = userRepository.findById(currentUserId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        CommunityMember member = new CommunityMember();
        member.setCommunity(community);
        member.setUser(user);
        member.setJoinedAt(LocalDateTime.now());
        memberRepository.save(member);
    }

    @Transactional
    public void leave(UUID currentUserId, UUID communityId) {
        CommunityMember member = memberRepository.findByCommunity_IdAndUser_Id(communityId, currentUserId)
                .orElseThrow(() -> new AppException("Not a member of this community", HttpStatus.NOT_FOUND));
        memberRepository.delete(member);
    }

    @Transactional
    public void markRead(UUID currentUserId, UUID communityId) {
        CommunityMember member = memberRepository.findByCommunity_IdAndUser_Id(communityId, currentUserId)
                .orElseThrow(() -> new AppException("Not a member of this community", HttpStatus.FORBIDDEN));
        member.setLastReadAt(LocalDateTime.now());
        memberRepository.save(member);
    }

    private CommunityDto toDto(Community c, CommunityMember member) {
        long members = c.getMemberCountOverride() != null
                ? c.getMemberCountOverride()
                : memberRepository.countByCommunity_Id(c.getId());

        var last = messageRepository.findTopByCommunity_IdOrderByCreatedAtDesc(c.getId()).orElse(null);
        String lastSender = last != null ? firstName(last.getSender().getFullName()) : null;
        String lastMessage = last != null ? last.getBody() : null;
        LocalDateTime time = last != null ? last.getCreatedAt() : c.getCreatedAt();

        long unread;
        if (member == null) {
            unread = 0;
        } else if (member.getLastReadAt() == null) {
            unread = messageRepository.countByCommunity_Id(c.getId());
        } else {
            unread = messageRepository.countByCommunity_IdAndCreatedAtAfter(c.getId(), member.getLastReadAt());
        }

        // Only the 5 avatars we render, then one batched PersonDto build.
        List<User> avatarUsers = memberRepository.findTop5ByCommunity_IdOrderByJoinedAtAsc(c.getId()).stream()
                .map(CommunityMember::getUser)
                .toList();
        List<PersonDto> avatars = personService.toPeople(avatarUsers);

        return new CommunityDto(
                c.getId(),
                c.getName(),
                c.getBadge(),
                c.getType(),
                (int) members,
                c.getOnlineCount(),
                lastSender,
                lastMessage,
                time,
                avatars,
                unread,
                c.getAutoJoinLabel(),
                member != null && c.getType() == CommunityType.SECTION,
                member != null && c.getType() == CommunityType.SCHOOL
        );
    }

    private String memberCountText(Community c) {
        if (c.getMemberCountOverride() != null) {
            return String.valueOf(c.getMemberCountOverride());
        }
        return String.valueOf(memberRepository.countByCommunity_Id(c.getId()));
    }

    private String firstName(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            return "";
        }
        return fullName.trim().split("\\s+")[0];
    }
}
