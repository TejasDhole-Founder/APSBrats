package com.apsconnect.api.career;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CareerEntryRepository extends JpaRepository<CareerEntry, UUID> {

    /** Loads the organization in the same query, so a long timeline is one SQL call. */
    @EntityGraph(attributePaths = "organization")
    List<CareerEntry> findByUserIdOrderByStartDateDesc(UUID userId);
}
