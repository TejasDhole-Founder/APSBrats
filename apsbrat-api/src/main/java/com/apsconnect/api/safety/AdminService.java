package com.apsconnect.api.safety;

import com.apsconnect.api.auth.AuthService;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.community.CommunityMember;
import com.apsconnect.api.community.CommunityMemberRepository;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.UserRole;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final ReportRepository reportRepository;
    private final ModerationActionRepository actionRepository;
    private final UserRepository userRepository;
    private final CommunityMemberRepository memberRepository;
    private final AuthService authService;

    @Transactional(readOnly = true)
    public List<ReportDto> listReports(String status) {
        List<Report> reports = (status == null || status.isBlank())
                ? reportRepository.findByOrderByCreatedAtDesc()
                : reportRepository.findByStatusOrderByCreatedAtDesc(status.trim().toUpperCase());
        return reports.stream().map(ReportDto::from).toList();
    }

    @Transactional
    public void resolveReport(UUID actorId, UUID reportId, String status, String reason) {
        Report report = reportRepository.findById(reportId)
                .orElseThrow(() -> new AppException("Report not found", HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND));
        String normalized = status == null || status.isBlank() ? "RESOLVED" : status.trim().toUpperCase();
        report.setStatus(normalized);
        reportRepository.save(report);
        log(actorId, report.getTargetUser() != null ? report.getTargetUser().getId() : null,
                "REPORT_" + normalized, reason, reportId);
    }

    @Transactional
    public void suspendUser(UUID actorId, UUID userId, int days, String reason) {
        User user = requireUser(userId);
        int span = Math.max(1, days);
        user.setSuspendedUntil(LocalDateTime.now().plusDays(span));
        userRepository.save(user);
        authService.revokeAllFor(userId);
        log(actorId, userId, "SUSPEND_" + span + "D", reason, null);
    }

    @Transactional
    public void banUser(UUID actorId, UUID userId, String reason) {
        requireAdmin(actorId);
        User user = requireUser(userId);
        user.setBannedAt(LocalDateTime.now());
        userRepository.save(user);
        authService.revokeAllFor(userId);
        log(actorId, userId, "BAN", reason, null);
    }

    @Transactional
    public void reinstateUser(UUID actorId, UUID userId) {
        User user = requireUser(userId);
        user.setBannedAt(null);
        user.setSuspendedUntil(null);
        userRepository.save(user);
        log(actorId, userId, "REINSTATE", null, null);
    }

    @Transactional
    public void setRole(UUID actorId, UUID userId, UserRole role) {
        requireAdmin(actorId);
        if (role == null) {
            throw new AppException("Role is required", HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR);
        }
        User user = requireUser(userId);
        user.setRole(role);
        userRepository.save(user);
        authService.revokeAllFor(userId);
        log(actorId, userId, "SET_ROLE_" + role.name(), null, null);
    }

    @Transactional
    public void removeCommunityMember(UUID actorId, UUID communityId, UUID userId, String reason) {
        CommunityMember member = memberRepository.findByCommunity_IdAndUser_Id(communityId, userId)
                .orElseThrow(() -> new AppException("Membership not found", HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND));
        memberRepository.delete(member);
        log(actorId, userId, "REMOVE_FROM_COMMUNITY", reason, null);
    }

    @Transactional(readOnly = true)
    public List<ModerationAction> recentActions(int limit) {
        int capped = limit <= 0 ? 50 : Math.min(limit, 200);
        return actionRepository.findByOrderByCreatedAtDesc(PageRequest.of(0, capped));
    }

    private User requireUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND));
    }

    private void requireAdmin(UUID actorId) {
        User actor = requireUser(actorId);
        if (actor.getRole() != UserRole.ADMIN) {
            throw new AppException("Requires administrator privileges", HttpStatus.FORBIDDEN, ErrorCode.FORBIDDEN);
        }
    }

    private void log(UUID actorId, UUID targetUserId, String action, String reason, UUID reportId) {
        ModerationAction record = new ModerationAction();
        record.setActorId(actorId);
        record.setTargetUserId(targetUserId);
        record.setAction(action);
        record.setReason(reason);
        record.setReportId(reportId);
        actionRepository.save(record);
    }
}
