package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CommunityRepository extends JpaRepository<Community, UUID> {
    List<Community> findByTypeIn(List<CommunityType> types);

    List<Community> findByNameContainingIgnoreCase(String name);
}
