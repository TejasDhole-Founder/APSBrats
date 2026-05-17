package com.apsconnect.api.user.history;

import com.apsconnect.api.school.School;
import com.apsconnect.api.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "user_school_history")
public class UserSchoolHistory {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "school_id")
    private School school;

    private short classFrom;
    private short classTo;
    private String section;
    private short batchStart;
    private short batchEnd;
    private boolean isPrimary;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (section != null) {
            section = section.toUpperCase();
        }
    }
}
