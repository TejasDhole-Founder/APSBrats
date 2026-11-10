package com.apsconnect.api.safety;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.community.CommunityChatService;
import com.apsconnect.api.community.PostService;
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
    private final PostService postService;
    private final CommunityChatService communityChatService;

    /** This many different people reporting a post, comment or chat message hides it until staff review. */
    private static final int AUTO_HIDE_REPORTERS = 3;

    @Transactional
    public UUID create(UUID reporterId, CreateReportRequest request) {
        ReportTargetType type = request.targetType();
        boolean content = type == ReportTargetType.POST || type == ReportTargetType.COMMENT
                || type == ReportTargetType.COMMUNITY_MESSAGE;
        if (content) {
            if (request.targetId() == null) {
                throw new AppException("Reported item not found", HttpStatus.NOT_FOUND);
            }
            if (type == ReportTargetType.COMMUNITY_MESSAGE) {
                communityChatService.requireReportable(reporterId, request.targetId());
            } else {
                postService.requireReportable(reporterId, type == ReportTargetType.POST, request.targetId());
            }
        }

        if (!content) {
            // A report about a person: someone else, and named.
            if (request.targetUserId() == null) {
                throw new AppException("Say who you're reporting", HttpStatus.BAD_REQUEST);
            }
            if (request.targetUserId().equals(reporterId)) {
                throw new AppException("You can't report yourself", HttpStatus.BAD_REQUEST);
            }
        }
        UUID target = content ? request.targetId() : request.targetUserId();
        var earlier = reportRepository.findExisting(reporterId, type.name(), target);
        if (earlier.isPresent()) {
            return earlier.get();
        }

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
        UUID id = reportRepository.save(report).getId();

        if (content && reportRepository.countDistinctReporters(type, request.targetId()) >= AUTO_HIDE_REPORTERS) {
            switch (type) {
                case POST -> postService.hidePost(request.targetId());
                case COMMENT -> postService.hideComment(request.targetId());
                default -> communityChatService.hide(request.targetId());
            }
        }
        return id;
    }
}
