package com.andexevents.users.service;

import com.andexevents.users.model.AdminAuditLogDto;
import com.andexevents.users.repo.AdminAuditLogRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class AdminAuditLogService {
    private final AdminAuditLogRepository adminAuditLogRepository;

    public AdminAuditLogService(AdminAuditLogRepository adminAuditLogRepository) {
        this.adminAuditLogRepository = adminAuditLogRepository;
    }

    public void logRoleChange(String actorUserId, String targetUserId, String fromRole, String toRole) {
        adminAuditLogRepository.insert(
                actorUserId,
                targetUserId,
                "USER_ROLE_CHANGED",
                Map.of(
                        "fromRole", fromRole,
                        "toRole", toRole
                )
        );
    }

            public void logSanctionCreated(
                String actorUserId,
                String targetUserId,
                String type,
                String reason,
                String expiresAt
            ) {
            adminAuditLogRepository.insert(
                actorUserId,
                targetUserId,
                "USER_SANCTION_CREATED",
                Map.of(
                    "type", type,
                    "reason", reason,
                    "expiresAt", expiresAt == null ? "PERMANENT" : expiresAt
                )
            );
            }

            public void logSanctionRevoked(String actorUserId, String targetUserId, String sanctionId) {
            adminAuditLogRepository.insert(
                actorUserId,
                targetUserId,
                "USER_SANCTION_REVOKED",
                Map.of(
                    "sanctionId", sanctionId
                )
            );
            }

    public List<AdminAuditLogDto> getRecent(int limit) {
        return adminAuditLogRepository.findRecent(limit);
    }
}
