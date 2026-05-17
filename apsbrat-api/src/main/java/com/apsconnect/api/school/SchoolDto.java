package com.apsconnect.api.school;

import java.util.UUID;

public record SchoolDto(
        UUID id,
        String name,
        String city,
        String state,
        String cantonment,
        String address,
        String schoolCode,
        String principalName,
        String phone,
        String email,
        String website,
        Boolean isActive
) {
    public static SchoolDto from(School school) {
        return new SchoolDto(
                school.getId(),
                school.getName(),
                school.getCity(),
                school.getState(),
                school.getCantonment(),
                school.getAddress(),
                school.getSchoolCode(),
                school.getPrincipalName(),
                school.getPhone(),
                school.getEmail(),
                school.getWebsite(),
                school.getIsActive()
        );
    }
}
