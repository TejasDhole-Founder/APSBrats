package com.apsconnect.api.community;

import com.apsconnect.api.school.School;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcType;
import org.hibernate.dialect.PostgreSQLEnumJdbcType;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "communities")
public class Community {
    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false)
    private String name;

    private String badge;

    @Enumerated(EnumType.STRING)
    @JdbcType(PostgreSQLEnumJdbcType.class)
    @Column(nullable = false, columnDefinition = "community_type")
    private CommunityType type;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "school_id")
    private School school;

    private String section;
    private Short batchStart;
    private Short batchEnd;
    private String subtitle;

    @Column(name = "auto_join_label")
    private String autoJoinLabel;

    @Column(name = "online_count", nullable = false)
    private int onlineCount;

    @Column(name = "member_count_override")
    private Integer memberCountOverride;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
