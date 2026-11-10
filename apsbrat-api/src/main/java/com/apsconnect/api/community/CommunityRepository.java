package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface CommunityRepository extends JpaRepository<Community, UUID> {

    /** The school communities of these schools. */
    List<Community> findBySchoolIdIn(Collection<UUID> schoolIds);

    /** How many communities of this type someone created (max 5 interest ones). */
    long countByCreatedByAndType(UUID createdBy, CommunityType type);

    boolean existsByTypeAndNameKey(CommunityType type, String nameKey);

    /** Discover: interest communities whose name contains the search, biggest first. */
    List<Community> findTop20ByTypeAndNameKeyContainingOrderByMemberCountDescNameAsc(
            CommunityType type, String fragment);

    /**
     * Changes member_count in the database itself (count = count + delta), so two
     * people joining at the same moment both count. Clears the loaded entities
     * afterwards so the next read sees the new number.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Community c SET c.memberCount = c.memberCount + :delta WHERE c.id = :id")
    void addToMemberCount(@Param("id") UUID id, @Param("delta") int delta);
}