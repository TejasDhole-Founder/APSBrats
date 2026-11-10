package com.apsconnect.api.career;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "job_titles")
public class JobTitle {
    @Id
    @GeneratedValue
    private UUID id;

    private String title;
    private String titleKey;
    private String jobFunction;
    private String status = "UNVERIFIED";
    private LocalDateTime createdAt = LocalDateTime.now();
}