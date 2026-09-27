package com.apsconnect.api.profile;

import com.apsconnect.api.user.history.Stream;
import com.apsconnect.api.user.history.UserSchoolHistory;

import java.util.UUID;

public record SchoolHistoryDto(
        UUID id,
        UUID schoolId,
        String schoolName,
        short classFrom,
        short classTo,
        String section,
        short batchStart,
        short batchEnd,
        Stream stream,
        boolean isPrimary
) {
    public static SchoolHistoryDto from(UserSchoolHistory h) {
        return new SchoolHistoryDto(
                h.getId(),
                h.getSchool() != null ? h.getSchool().getId() : null,
                h.getSchool() != null ? h.getSchool().getName() : null,
                h.getClassFrom(),
                h.getClassTo(),
                h.getSection(),
                h.getBatchStart(),
                h.getBatchEnd(),
                h.getStream(),
                h.isPrimary()
        );
    }
}
