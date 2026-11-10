package com.apsconnect.api.community;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface PostLikeRepository extends JpaRepository<PostLike, PostLike.Key> {

    /** Adds the like unless it's already there. Returns 1 if a row was added, 0 if not. */
    @Modifying
    @Query(value = "INSERT INTO post_likes (post_id, user_id) VALUES (:postId, :userId) ON CONFLICT DO NOTHING",
            nativeQuery = true)
    int insertIfAbsent(@Param("postId") UUID postId, @Param("userId") UUID userId);

    /** Removes the like. Returns 1 if a row was removed, 0 if there was none. */
    @Modifying
    @Query("DELETE FROM PostLike l WHERE l.postId = :postId AND l.userId = :userId")
    int deleteLike(@Param("postId") UUID postId, @Param("userId") UUID userId);

    /** Which of these posts I've liked (one query for a whole page). */
    @Query("SELECT l.postId FROM PostLike l WHERE l.userId = :userId AND l.postId IN :postIds")
    List<UUID> findLikedPostIds(@Param("userId") UUID userId, @Param("postIds") Collection<UUID> postIds);
}
