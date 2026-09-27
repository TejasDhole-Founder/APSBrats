package com.apsconnect.api.connection;

/**
 * Life of a connection row. Only PENDING and ACCEPTED are "live"; the other
 * three keep the history of a pair so a later request reuses the same row.
 */
public enum ConnectionStatus {
    PENDING,
    ACCEPTED,
    /** Addressee said no. */
    DECLINED,
    /** Requester took the request back. */
    WITHDRAWN,
    /** An accepted connection was removed by either side (or by a block). */
    REMOVED;

    public boolean isLive() {
        return this == PENDING || this == ACCEPTED;
    }
}
