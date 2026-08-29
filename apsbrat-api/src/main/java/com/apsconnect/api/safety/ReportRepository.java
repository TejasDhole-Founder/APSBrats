package com.apsconnect.api.safety;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ReportRepository extends JpaRepository<Report, UUID> {
    List<Report> findByStatusOrderByCreatedAtDesc(String status);

    List<Report> findByOrderByCreatedAtDesc();
}
