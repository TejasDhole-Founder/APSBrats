package com.apsconnect.api.safety;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ReportService {

    private final ReportRepository reportRepository;
    private final UserRepository userRepository;

    @Transactional
    public UUID create(UUID reporterId, CreateReportRequest request) {
        Report report = new Report();
        report.setReporter(userRepository.getReferenceById(reporterId));
        report.setTargetType(request.targetType());
        report.setTargetId(request.targetId());
        if (request.targetUserId() != null) {
            report.setTargetUser(userRepository.findById(request.targetUserId())
                    .orElseThrow(() -> new AppException("Reported user not found", HttpStatus.NOT_FOUND)));
        }
        report.setReason(request.reason().trim());
        report.setDetails(request.details());
        return reportRepository.save(report).getId();
    }
}
