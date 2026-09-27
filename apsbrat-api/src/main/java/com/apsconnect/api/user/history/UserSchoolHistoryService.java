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
    private final com.apsconnect.api.circle.CircleCache circleCache;

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

        String overlap = overlapProblem(request.items());
        if (overlap != null) {
            throw new AppException(overlap, HttpStatus.BAD_REQUEST);
        }

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
            history.setSection(item.section() == null || item.section().isBlank() ? null : item.section().trim().toUpperCase());
            history.setStream(item.stream());
            history.setBatchStart(item.batchStart());
            history.setBatchEnd(item.batchEnd());
            history.setPrimary(item.isPrimary() != null && item.isPrimary());
            items.add(history);
        }

        userSchoolHistoryRepository.deleteAllByUser_Id(userId);
        userSchoolHistoryRepository.saveAll(items);
        circleCache.evictUser(userId);
    }

    /**
     * A student is in one school at a time, so two entries may not share a class
     * or an academic year. Sessions run April to March, so a school ending in 2019
     * and the next starting in 2019 is fine; 8-9 in 2018-2020 and 10-12 in
     * 2019-2021 is not. Returns the problem, or null when the list is consistent.
     */
    static String overlapProblem(List<SaveSchoolHistoryItemRequest> items) {
        if (items == null) {
            return null;
        }
        for (int i = 0; i < items.size(); i++) {
            for (int j = i + 1; j < items.size(); j++) {
                SaveSchoolHistoryItemRequest a = items.get(i);
                SaveSchoolHistoryItemRequest b = items.get(j);
                if (a.classFrom() <= b.classTo() && b.classFrom() <= a.classTo()) {
                    return "School entries overlap in classes (" + range(a) + " and " + range(b)
                            + "). Each class can belong to only one school.";
                }
                if (a.batchStart() < b.batchEnd() && b.batchStart() < a.batchEnd()) {
                    return "School entries overlap in years (" + years(a) + " and " + years(b)
                            + "). You can only be in one school at a time.";
                }
                boolean aFirst = a.classTo() < b.classFrom();
                int earlierEnd = aFirst ? a.batchEnd() : b.batchEnd();
                int laterStart = aFirst ? b.batchStart() : a.batchStart();
                if (earlierEnd > laterStart) {
                    return "School entries out of order (" + range(a) + " " + years(a) + ", "
                            + range(b) + " " + years(b) + "). Lower classes must be in the earlier years.";
                }
            }
        }
        return null;
    }

    private static String range(SaveSchoolHistoryItemRequest i) {
        return "Class " + i.classFrom() + "-" + i.classTo();
    }

    private static String years(SaveSchoolHistoryItemRequest i) {
        return i.batchStart() + "-" + i.batchEnd();
    }

    private void validate(SaveSchoolHistoryItemRequest item) {
        if (item.classTo() < item.classFrom()) {
            throw new AppException("classTo must be >= classFrom", HttpStatus.BAD_REQUEST);
        }
        if (item.batchEnd() < item.batchStart()) {
            throw new AppException("batchEnd must be >= batchStart", HttpStatus.BAD_REQUEST);
        }
        String streamProblem = streamProblem(item);
        if (streamProblem != null) {
            throw new AppException(streamProblem, HttpStatus.BAD_REQUEST);
        }
    }

    /** Stream is chosen in Class 11, so it is required from Class 11 up and not allowed below. */
    static String streamProblem(SaveSchoolHistoryItemRequest item) {
        boolean seniorSecondary = item.classTo() >= Stream.FIRST_CLASS;
        if (seniorSecondary && item.stream() == null) {
            return "Stream is required for Class 11 and 12 (" + range(item) + ").";
        }
        if (!seniorSecondary && item.stream() != null) {
            return "Stream only applies to Class 11 and 12 (" + range(item) + ").";
        }
        return null;
    }
}
