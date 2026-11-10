package com.apsconnect.api.feed;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface FeedEventRepository extends JpaRepository<FeedEvent, UUID> {
    /** Actor fetched in the same query: it's read for every event. */
    @EntityGraph(attributePaths = "actor")
    List<FeedEvent> findAllByOrderByCreatedAtDesc(Pageable pageable);
}
