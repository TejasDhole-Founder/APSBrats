package com.apsconnect.api.community;

import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface PostRepository extends JpaRepository<Post, UUID> {

    /**
     * Newest posts in these communities, older than the cursor. One query serves
     * both a community page (one id) and the Home feed (all my communities).
     * Ask for one more than a page to know whether there is a next page.
     * A community page leaves pinned posts out (they're shown on top); Home keeps them.
     */
    @Query("""
            SELECT p FROM Post p
            WHERE p.communityId IN :communityIds
              AND p.status = :status
              AND p.createdAt < :before
              AND p.authorId NOT IN :hiddenAuthors
              AND (:includePinned = TRUE OR p.pinnedAt IS NULL)
            ORDER BY p.createdAt DESC
            """)
    List<Post> findPage(@Param("communityIds") Collection<UUID> communityIds,
                        @Param("status") ContentStatus status,
                        @Param("before") LocalDateTime before,
                        @Param("hiddenAuthors") Collection<UUID> hiddenAuthors,
                        @Param("includePinned") boolean includePinned,
                        Pageable pageable);

    /**
     * Popular: likes + 2 x comments, over posts from [since] on, paged by offset
     * (a score isn't a stable cursor). Pinned posts are shown separately.
     */
    // ponytail: offset paging can repeat/skip a post if scores move between pages; fine at community scale.
    @Query(value = """
            SELECT * FROM posts p
            WHERE p.community_id = :communityId
              AND p.status = 'ACTIVE'
              AND p.pinned_at IS NULL
              AND p.created_at >= :since
              AND p.author_id NOT IN (:hiddenAuthors)
            ORDER BY p.like_count + 2 * p.comment_count DESC, p.created_at DESC, p.id
            LIMIT :limit OFFSET :offset
            """, nativeQuery = true)
    List<Post> findPopularPage(@Param("communityId") UUID communityId,
                               @Param("since") LocalDateTime since,
                               @Param("hiddenAuthors") Collection<UUID> hiddenAuthors,
                               @Param("limit") int limit,
                               @Param("offset") int offset);

    List<Post> findByCommunityIdAndStatusAndPinnedAtIsNotNullOrderByPinnedAtDesc(UUID communityId, ContentStatus status);

    /**
     * A community's memory posts, by year (newest year first), then newest post.
     * Year and category are optional filters. A Slice knows if another page exists.
     */
    @Query("""
            SELECT p FROM Post p
            WHERE p.communityId = :communityId
              AND p.memoryCategory IS NOT NULL
              AND (:year IS NULL OR p.memoryYear = :year)
              AND (:category IS NULL OR p.memoryCategory = :category)
              AND p.status = :status
              AND p.authorId NOT IN :hiddenAuthors
            ORDER BY p.memoryYear DESC, p.createdAt DESC, p.id
            """)
    Slice<Post> findMemoryPage(@Param("communityId") UUID communityId,
                               @Param("year") Short year,
                               @Param("category") MemoryCategory category,
                               @Param("status") ContentStatus status,
                               @Param("hiddenAuthors") Collection<UUID> hiddenAuthors,
                               Pageable pageable);

    /** Rows of (eventId, count) of active posts shared from these events. */
    @Query("SELECT p.eventId, COUNT(p) FROM Post p WHERE p.eventId IN :eventIds AND p.status = :status GROUP BY p.eventId")
    List<Object[]> countByEvent(@Param("eventIds") Collection<UUID> eventIds, @Param("status") ContentStatus status);

    /** Years that have memories in this community, newest first. */
    @Query("""
            SELECT DISTINCT p.memoryYear FROM Post p
            WHERE p.communityId = :communityId AND p.memoryCategory IS NOT NULL AND p.status = :status
            ORDER BY p.memoryYear DESC
            """)
    List<Short> findMemoryYears(@Param("communityId") UUID communityId, @Param("status") ContentStatus status);

    /** An event's posts (its photos), newest first, older than the cursor. */
    @Query("""
            SELECT p FROM Post p
            WHERE p.eventId = :eventId
              AND p.status = :status
              AND p.createdAt < :before
              AND p.authorId NOT IN :hiddenAuthors
            ORDER BY p.createdAt DESC
            """)
    List<Post> findEventPage(@Param("eventId") UUID eventId,
                             @Param("status") ContentStatus status,
                             @Param("before") LocalDateTime before,
                             @Param("hiddenAuthors") Collection<UUID> hiddenAuthors,
                             Pageable pageable);

    long countByCommunityIdAndStatusAndPinnedAtIsNotNull(UUID communityId, ContentStatus status);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Post p SET p.likeCount = p.likeCount + :delta WHERE p.id = :id")
    void addToLikeCount(@Param("id") UUID id, @Param("delta") int delta);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Post p SET p.commentCount = p.commentCount + :delta WHERE p.id = :id")
    void addToCommentCount(@Param("id") UUID id, @Param("delta") int delta);
}
