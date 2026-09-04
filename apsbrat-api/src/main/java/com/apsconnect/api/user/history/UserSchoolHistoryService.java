package com.apsconnect.api.user.history;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.profile.SchoolHistoryDto;
import com.apsconnect.api.school.School;
import com.apsconnect.api.school.SchoolRepository;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserSchoolHistoryService {
    private final UserRepository userRepository;
    private final SchoolRepository schoolRepository;
    private final UserSchoolHistoryRepository userSchoolHistoryRepository;

    /** A user's schools, most recent first. Shared by the profile, the data export and the GET endpoint. */
    @Transactional(readOnly = true)
    public List<SchoolHistoryDto> getSchoolHistory(UUID userId) {
        if (!userRepository.existsById(userId)) {
            throw new AppException("User not found", HttpStatus.NOT_FOUND);
        }
        return userSchoolHistoryRepository.findAllByUser_Id(userId).stream()
                .sorted(Comparator.comparingInt(UserSchoolHistory::getBatchEnd).reversed())
                .map(SchoolHistoryDto::from)
                .toList();
    }

    @Transactional
    public void replaceSchoolHistory(UUID userId, SaveSchoolHistoryRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        List<UserSchoolHistory> items = new ArrayList<>();
        for (SaveSchoolHistoryItemRequest item : request.items()) {
            validate(item);

            School school = schoolRepository.findById(item.schoolId())
                    .orElseThrow(() -> new AppException("School not found: " + item.schoolId(), HttpStatus.BAD_REQUEST));

            UserSchoolHistory history = new UserSchoolHistory();
            history.setUser(user);
            history.setSchool(school);
            history.setClassFrom(item.classFrom());
            history.setClassTo(item.classTo());
            history.setSection(item.section());
            history.setBatchStart(item.batchStart());
            history.setBatchEnd(item.batchEnd());
            history.setPrimary(item.isPrimary() != null && item.isPrimary());
            items.add(history);
        }

        userSchoolHistoryRepository.deleteAllByUser_Id(userId);
        userSchoolHistoryRepository.saveAll(items);
    }

    private void validate(SaveSchoolHistoryItemRequest item) {
        if (item.classTo() < item.classFrom()) {
            throw new AppException("classTo must be >= classFrom", HttpStatus.BAD_REQUEST);
        }
        if (item.batchEnd() < item.batchStart()) {
            throw new AppException("batchEnd must be >= batchStart", HttpStatus.BAD_REQUEST);
        }
    }
}
