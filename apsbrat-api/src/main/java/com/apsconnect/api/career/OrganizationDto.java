package com.apsconnect.api.career;

import java.util.UUID;

public record OrganizationDto(UUID id, String name, String industry, boolean verified) {
    public static OrganizationDto from(Organization o) {
        return new OrganizationDto(o.getId(), o.getName(), o.getIndustry(), "VERIFIED".equals(o.getStatus()));
    }
}