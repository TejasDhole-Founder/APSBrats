package com.apsconnect.api.safety;

import com.apsconnect.api.user.UserRole;

public final class AdminRequests {
    private AdminRequests() {
    }

    public record ResolveReportRequest(String status, String reason) {
    }

    public record SuspendRequest(int days, String reason) {
    }

    public record BanRequest(String reason) {
    }

    public record SetRoleRequest(UserRole role) {
    }
}
