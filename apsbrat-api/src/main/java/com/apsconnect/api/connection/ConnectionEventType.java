package com.apsconnect.api.connection;

/** One step in the life of a relationship; stored in connection_events. */
public enum ConnectionEventType {
    REQUESTED,
    ACCEPTED,
    DECLINED,
    WITHDRAWN,
    REMOVED
}
