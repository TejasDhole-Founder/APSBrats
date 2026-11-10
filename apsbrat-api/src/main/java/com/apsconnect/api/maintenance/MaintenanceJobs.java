package com.apsconnect.api.maintenance;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.annotation.Transactional;

/**
 * Nightly clean-up of rows nobody can use any more. Runs in every instance: deletes
 * are idempotent, so two instances running it at once is harmless (one API instance today).
 */
@Slf4j
@Configuration
@EnableScheduling
@RequiredArgsConstructor
public class MaintenanceJobs {

    static final String DELETE_OLD_OTPS =
            "DELETE FROM otp_codes WHERE expires_at < now() - interval '1 day'";
    static final String DELETE_OLD_READ_NOTIFICATIONS =
            "DELETE FROM notifications WHERE is_read = TRUE AND created_at < now() - interval '180 days'";

    private final JdbcTemplate jdbc;

    @Scheduled(cron = "${app.maintenance.cron:0 30 3 * * *}", zone = "Asia/Kolkata")
    @Transactional
    public void purgeExpired() {
        int otps = jdbc.update(DELETE_OLD_OTPS);
        int notifications = jdbc.update(DELETE_OLD_READ_NOTIFICATIONS);
        log.info("Maintenance: removed {} expired OTP codes and {} read notifications older than 180 days",
                otps, notifications);
    }
}
