package com.apsconnect.api.connection;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface ConnectionRepository extends JpaRepository<Connection, UUID> {

    // `status` is a Postgres enum column. An enum literal written inside JPQL is
    // sent as plain text and Postgres rejects "connection_status = varchar", so the
    // status is always passed as a bound parameter (Hibernate then binds it with
    // the enum JDBC type). Native queries compare against a quoted literal instead.

    @Query("""
            SELECT c FROM Connection c
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
            WHERE c.status = :status AND c.addressee.id = :userId
            ORDER BY c.createdAt DESC
            """)
    List<Connection> findIncomingWithStatus(@Param("userId") UUID userId,
                                            @Param("status") ConnectionStatus status);

    /** Requests waiting for me to answer. */
    default List<Connection> findPendingIncoming(UUID userId) {
        return findIncomingWithStatus(userId, ConnectionStatus.PENDING);
    }

    @Query("""
            SELECT c FROM Connection c
            WHERE c.status = :status AND c.requester.id = :userId
            ORDER BY c.createdAt DESC
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

    /**
     * The one row for this pair, whatever its status (there is at most one because
     * of the unique constraint and because a re-request reuses the old row).
     */
    @Query("""
            SELECT c FROM Connection c
            WHERE (c.requester.id = :a AND c.addressee.id = :b)
               OR (c.requester.id = :b AND c.addressee.id = :a)
            """)
    List<Connection> findBetween(@Param("a") UUID a, @Param("b") UUID b);

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

    /** Ids of the people connected to both :me and :other. */
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
}
