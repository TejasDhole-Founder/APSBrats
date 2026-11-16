package com.apsconnect.api.connection;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConnectionRepository extends JpaRepository<Connection, UUID> {

    // `status` is a Postgres enum column. An enum literal written inside JPQL is
    // sent as plain text and Postgres rejects "connection_status = varchar", so the
    // status is always passed as a bound parameter (Hibernate then binds it with
    // the enum JDBC type). Native queries compare against a quoted literal instead.

    /** The one row for this pair (see {@link UserPair#of}), whatever its status. */
    @Query("SELECT c FROM Connection c WHERE c.userLowId = :low AND c.userHighId = :high")
    Optional<Connection> findByPair(@Param("low") UUID low, @Param("high") UUID high);

    default Optional<Connection> findBetween(UUID a, UUID b) {
        UserPair pair = UserPair.of(a, b);
        return findByPair(pair.low(), pair.high());
    }

    /**
     * Waits until no other transaction holds this pair, then holds it until this one ends.
     * Every change to a pair (request, accept, end, block) takes it first, so two people acting
     * on each other at the same moment, on one server or several, run one after the other.
     * Returns 1; the select is only there so Spring Data can run the call.
     */
    @Query(value = "SELECT 1 FROM (SELECT pg_advisory_xact_lock(hashtextextended(:key, 0))) AS locked",
            nativeQuery = true)
    int lockPair(@Param("key") String key);

    default void lock(UserPair pair) {
        lockPair(pair.lockKey());
    }

    @Query("""
            SELECT c FROM Connection c
            JOIN FETCH c.requester JOIN FETCH c.addressee
            WHERE c.status = :status
              AND (c.requester.id = :userId OR c.addressee.id = :userId)
            ORDER BY c.acceptedAt DESC, c.createdAt DESC
            """)
    List<Connection> findForUserWithStatus(@Param("userId") UUID userId,
                                           @Param("status") ConnectionStatus status);

    default List<Connection> findAcceptedForUser(UUID userId) {
        return findForUserWithStatus(userId, ConnectionStatus.ACCEPTED);
    }

    @Query("""
            SELECT c FROM Connection c
            JOIN FETCH c.requester JOIN FETCH c.addressee
            WHERE c.status = :status AND c.addressee.id = :userId
            ORDER BY c.requestedAt DESC
            """)
    List<Connection> findIncomingWithStatus(@Param("userId") UUID userId,
                                            @Param("status") ConnectionStatus status);

    /** Requests waiting for me to answer. */
    default List<Connection> findPendingIncoming(UUID userId) {
        return findIncomingWithStatus(userId, ConnectionStatus.PENDING);
    }

    @Query("""
            SELECT c FROM Connection c
            JOIN FETCH c.requester JOIN FETCH c.addressee
            WHERE c.status = :status AND c.requester.id = :userId
            ORDER BY c.requestedAt DESC
            """)
    List<Connection> findOutgoingWithStatus(@Param("userId") UUID userId,
                                            @Param("status") ConnectionStatus status);

    /** Requests I sent that nobody has answered yet. */
    default List<Connection> findPendingSent(UUID userId) {
        return findOutgoingWithStatus(userId, ConnectionStatus.PENDING);
    }

    @Query("""
            SELECT COUNT(c) FROM Connection c
            WHERE c.status = :status
              AND (c.requester.id = :userId OR c.addressee.id = :userId)
            """)
    long countForUserWithStatus(@Param("userId") UUID userId,
                                @Param("status") ConnectionStatus status);

    default long countAcceptedForUser(UUID userId) {
        return countForUserWithStatus(userId, ConnectionStatus.ACCEPTED);
    }

    @Query("SELECT COUNT(c) FROM Connection c WHERE c.status = :status AND c.addressee.id = :userId")
    long countIncomingWithStatus(@Param("userId") UUID userId, @Param("status") ConnectionStatus status);

    @Query("SELECT COUNT(c) FROM Connection c WHERE c.status = :status AND c.requester.id = :userId")
    long countOutgoingWithStatus(@Param("userId") UUID userId, @Param("status") ConnectionStatus status);

    /** Live rows (pending or accepted) between :me and any of :ids, one query for a page of people. */
    @Query("""
            SELECT c FROM Connection c
            WHERE c.status IN :live
              AND ((c.requester.id = :me AND c.addressee.id IN :ids)
                OR (c.addressee.id = :me AND c.requester.id IN :ids))
            """)
    List<Connection> findLiveWithIds(@Param("me") UUID me, @Param("ids") Collection<UUID> ids,
                                     @Param("live") Collection<ConnectionStatus> live);

    default List<Connection> findLiveWithIds(UUID me, Collection<UUID> ids) {
        return findLiveWithIds(me, ids, List.of(ConnectionStatus.PENDING, ConnectionStatus.ACCEPTED));
    }

    /** Ids of everyone I am connected to (accepted, either direction). */
    @Query(value = """
            SELECT CASE WHEN requester_id = :me THEN addressee_id ELSE requester_id END
            FROM connections
            WHERE status = 'ACCEPTED' AND (requester_id = :me OR addressee_id = :me)
            """, nativeQuery = true)
    List<UUID> findFriendIds(@Param("me") UUID me);

    /**
     * Mutual connections between :me and each candidate id, in one round trip.
     * Native SQL: the connection row is stored once and read from both sides, so
     * each candidate's friends are collected from both columns and intersected
     * with :me's friends. Rows: [candidate uuid, count].
     */
    @Query(value = """
            WITH mine AS (
                SELECT CASE WHEN requester_id = :me THEN addressee_id ELSE requester_id END AS friend
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :me OR addressee_id = :me)
            ),
            theirs AS (
                SELECT requester_id AS person, addressee_id AS friend
                FROM connections WHERE status = 'ACCEPTED' AND requester_id IN (:ids)
                UNION ALL
                SELECT addressee_id AS person, requester_id AS friend
                FROM connections WHERE status = 'ACCEPTED' AND addressee_id IN (:ids)
            )
            SELECT t.person, COUNT(*)
            FROM theirs t JOIN mine m ON m.friend = t.friend
            WHERE t.friend <> t.person
            GROUP BY t.person
            """, nativeQuery = true)
    List<Object[]> countMutual(@Param("me") UUID me, @Param("ids") Collection<UUID> ids);

    /** Ids of the people connected to both :me and :other (everyone, no page). */
    @Query(value = """
            WITH mine AS (
                SELECT CASE WHEN requester_id = :me THEN addressee_id ELSE requester_id END AS friend
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :me OR addressee_id = :me)
            ),
            theirs AS (
                SELECT CASE WHEN requester_id = :other THEN addressee_id ELSE requester_id END AS friend
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :other OR addressee_id = :other)
            )
            SELECT m.friend FROM mine m JOIN theirs t ON t.friend = m.friend
            WHERE m.friend <> :me AND m.friend <> :other
            """, nativeQuery = true)
    List<UUID> findMutualIds(@Param("me") UUID me, @Param("other") UUID other);

    /** How many people are connected to both :me and :other. Counts only people with a live account. */
    @Query(value = """
            SELECT COUNT(*) FROM (
                SELECT CASE WHEN requester_id = :me THEN addressee_id ELSE requester_id END AS friend
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :me OR addressee_id = :me)
                INTERSECT
                SELECT CASE WHEN requester_id = :other THEN addressee_id ELSE requester_id END
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :other OR addressee_id = :other)
            ) common
            JOIN users u ON u.id = common.friend AND u.deleted_at IS NULL
            """, nativeQuery = true)
    long countMutualBetween(@Param("me") UUID me, @Param("other") UUID other);

    /**
     * One page of the people connected to both :me and :other, A to Z.
     * Rows: [user id, lower(full_name)]. The pair (lower name, id) is the sort key, so the
     * order is stable; pass the last row's pair back as :afterName / :afterId for the next
     * page (both null for the first). Null parameters are cast so Postgres can type them.
     */
    @Query(value = """
            SELECT u.id, lower(u.full_name)
            FROM (
                SELECT CASE WHEN requester_id = :me THEN addressee_id ELSE requester_id END AS friend
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :me OR addressee_id = :me)
                INTERSECT
                SELECT CASE WHEN requester_id = :other THEN addressee_id ELSE requester_id END
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :other OR addressee_id = :other)
            ) common
            JOIN users u ON u.id = common.friend AND u.deleted_at IS NULL
            WHERE CAST(:afterName AS text) IS NULL
               OR (lower(u.full_name), u.id) > (CAST(:afterName AS text), CAST(:afterId AS uuid))
            ORDER BY lower(u.full_name), u.id
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findMutualPage(@Param("me") UUID me, @Param("other") UUID other,
                                  @Param("afterName") String afterName, @Param("afterId") String afterId,
                                  @Param("limit") int limit);

    /** One page of my connections, A to Z, with the same stable sort key and cursor as {@link #findMutualPage}. */
    @Query(value = """
            SELECT u.id, lower(u.full_name)
            FROM (
                SELECT CASE WHEN requester_id = :me THEN addressee_id ELSE requester_id END AS friend
                FROM connections
                WHERE status = 'ACCEPTED' AND (requester_id = :me OR addressee_id = :me)
            ) mine
            JOIN users u ON u.id = mine.friend AND u.deleted_at IS NULL
            WHERE CAST(:afterName AS text) IS NULL
               OR (lower(u.full_name), u.id) > (CAST(:afterName AS text), CAST(:afterId AS uuid))
            ORDER BY lower(u.full_name), u.id
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findFriendsPage(@Param("me") UUID me,
                                   @Param("afterName") String afterName, @Param("afterId") String afterId,
                                   @Param("limit") int limit);

    /**
     * One page of the requests waiting for me, newest first.
     * Rows: [requester id, requested_at, connection id]. The pair (requested_at, id) is the sort key;
     * pass the last row's pair back as :afterAt / :afterId for the next page (both null for the first).
     */
    @Query(value = """
            SELECT c.requester_id, c.requested_at, c.id
            FROM connections c
            JOIN users u ON u.id = c.requester_id AND u.deleted_at IS NULL
            WHERE c.status = 'PENDING' AND c.addressee_id = :me
              AND (CAST(:afterAt AS timestamp) IS NULL
                   OR (c.requested_at, c.id) < (CAST(:afterAt AS timestamp), CAST(:afterId AS uuid)))
            ORDER BY c.requested_at DESC, c.id DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findReceivedPage(@Param("me") UUID me,
                                    @Param("afterAt") String afterAt, @Param("afterId") String afterId,
                                    @Param("limit") int limit);

    /** One page of the requests I sent that nobody has answered, newest first; same key and cursor as {@link #findReceivedPage}. Rows: [addressee id, requested_at, connection id]. */
    @Query(value = """
            SELECT c.addressee_id, c.requested_at, c.id
            FROM connections c
            JOIN users u ON u.id = c.addressee_id AND u.deleted_at IS NULL
            WHERE c.status = 'PENDING' AND c.requester_id = :me
              AND (CAST(:afterAt AS timestamp) IS NULL
                   OR (c.requested_at, c.id) < (CAST(:afterAt AS timestamp), CAST(:afterId AS uuid)))
            ORDER BY c.requested_at DESC, c.id DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findSentPage(@Param("me") UUID me,
                                @Param("afterAt") String afterAt, @Param("afterId") String afterId,
                                @Param("limit") int limit);
}
