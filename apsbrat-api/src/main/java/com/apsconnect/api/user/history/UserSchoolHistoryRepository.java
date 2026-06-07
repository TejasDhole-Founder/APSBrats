package com.apsconnect.api.user.history;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface UserSchoolHistoryRepository extends JpaRepository<UserSchoolHistory, UUID> {
    void deleteAllByUser_Id(UUID userId);

    List<UserSchoolHistory> findAllByUser_Id(UUID userId);

    long countByUser_Id(UUID userId);

    // Batch loader (one query, school eager-joined) to avoid N+1 when building many PersonDtos.
    @Query("SELECT h FROM UserSchoolHistory h JOIN FETCH h.school WHERE h.user.id IN :ids")
    List<UserSchoolHistory> findAllWithSchoolByUserIds(@Param("ids") Collection<UUID> ids);
}
