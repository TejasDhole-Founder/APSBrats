package com.apsconnect.api.safety;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ModerationActionRepository extends JpaRepository<ModerationAction, UUID> {
    List<ModerationAction> findByOrderByCreatedAtDesc(Pageable pageable);
}
