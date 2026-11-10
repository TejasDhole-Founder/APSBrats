package com.apsconnect.api.community;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

/** One row = this person is in this community. The key is the pair of ids. */
@Getter
@Setter
@Entity
@Table(name = "community_members")
@IdClass(CommunityMember.Key.class)
public class CommunityMember {
    @Id
    private UUID communityId;

    @Id
    private UUID userId;

    @Enumerated(EnumType.STRING)
    private MemberRole role = MemberRole.MEMBER;

    private LocalDateTime joinedAt = LocalDateTime.now();

    /** Read the group chat up to here; null = nothing read since joining. */
    private LocalDateTime chatReadAt;

    /** The two-column primary key, as one object (JPA needs this for findById). */
    @EqualsAndHashCode
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Key implements Serializable {
        private UUID communityId;
        private UUID userId;
    }
}