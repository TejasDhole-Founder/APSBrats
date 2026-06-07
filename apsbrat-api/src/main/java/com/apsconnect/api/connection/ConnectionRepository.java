package com.apsconnect.api.connection;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConnectionRepository extends JpaRepository<Connection, UUID> {

    Optional<Connection> findByRequester_IdAndAddressee_Id(UUID requesterId, UUID addresseeId);

    @Query("""
            SELECT c FROM Connection c
            WHERE c.status = com.apsconnect.api.connection.ConnectionStatus.ACCEPTED
              AND (c.requester.id = :userId OR c.addressee.id = :userId)
            ORDER BY c.createdAt DESC
            """)
    List<Connection> findAcceptedForUser(@Param("userId") UUID userId);

    @Query("""
            SELECT c FROM Connection c
            WHERE c.status = com.apsconnect.api.connection.ConnectionStatus.PENDING
              AND c.addressee.id = :userId
            ORDER BY c.createdAt DESC
            """)
    List<Connection> findPendingIncoming(@Param("userId") UUID userId);

    @Query("""
            SELECT COUNT(c) FROM Connection c
            WHERE c.status = com.apsconnect.api.connection.ConnectionStatus.ACCEPTED
              AND (c.requester.id = :userId OR c.addressee.id = :userId)
            """)
    long countAcceptedForUser(@Param("userId") UUID userId);

    // Single round-trip for status checks (either direction).
    @Query("""
            SELECT c FROM Connection c
            WHERE (c.requester.id = :a AND c.addressee.id = :b)
               OR (c.requester.id = :b AND c.addressee.id = :a)
            """)
    List<Connection> findBetween(@Param("a") UUID a, @Param("b") UUID b);
}
