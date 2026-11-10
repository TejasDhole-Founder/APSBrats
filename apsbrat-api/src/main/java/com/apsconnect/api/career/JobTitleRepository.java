package com.apsconnect.api.career;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface JobTitleRepository extends JpaRepository<JobTitle, UUID> {
    Optional<JobTitle> findByTitleKey(String titleKey);
}