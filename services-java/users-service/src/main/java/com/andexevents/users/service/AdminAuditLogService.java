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

    public List<AdminAuditLogDto> getRecent(int limit) {
        return adminAuditLogRepository.findRecent(limit);
    }
}
