package com.apsconnect.api.connection;

import java.util.UUID;

/**
 * Two users in a fixed order, so a relationship between them has one identity no matter
 * who asked whom: (Arjun, Rahul) and (Rahul, Arjun) are the same pair.
 *
 * <p>The order must match Postgres, whose {@code uuid} type compares the 16 bytes as unsigned
 * values (the {@code user_low_id < user_high_id} check relies on it). {@link UUID#compareTo}
 * compares signed longs and gives a different order, so compare the canonical lowercase text
 * instead: its character order is the same as the byte order.
 */
record UserPair(UUID low, UUID high) {

    static UserPair of(UUID a, UUID b) {
        return a.toString().compareTo(b.toString()) <= 0 ? new UserPair(a, b) : new UserPair(b, a);
    }

    /** One lock key per pair for {@code pg_advisory_xact_lock}. */
    String lockKey() {
        return "connection:" + low + ":" + high;
    }
}
