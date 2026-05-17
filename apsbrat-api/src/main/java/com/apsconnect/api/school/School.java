package com.apsconnect.api.school;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Entity
@Table(name = "schools")
public class School {
    @Id
    @GeneratedValue
    private UUID id;

    private String name;
    private String city;
    private String state;
    private String cantonment;
    private String address;
    private String schoolCode;
    private String principalName;
    private String phone;
    private String email;
    private String website;
    private Boolean isActive;
    private LocalDateTime createdAt;
}
