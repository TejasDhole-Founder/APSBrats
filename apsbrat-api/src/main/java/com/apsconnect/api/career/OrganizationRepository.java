package com.apsconnect.api.career;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface OrganizationRepository extends JpaRepository<Organization, UUID> {

    Optional<Organization> findByTypeAndNameKey(OrgType type, String nameKey);

    /** Autocomplete: VERIFIED sorts before UNVERIFIED when status is descending. */
    List<Organization> findTop10ByTypeAndNameKeyContainingOrderByStatusDescNameKeyAsc(
            OrgType type, String fragment);
}