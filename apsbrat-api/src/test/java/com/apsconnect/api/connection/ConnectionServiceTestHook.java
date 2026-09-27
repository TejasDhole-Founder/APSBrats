package com.apsconnect.api.connection;

import java.util.UUID;

/** Exposes the package-private status rule to tests in other packages. */
public final class ConnectionServiceTestHook {
    private ConnectionServiceTestHook() {
    }

    public static ConnectionStatus closedStatus(Connection connection, UUID actor) {
        return ConnectionService.closedStatus(connection, actor);
    }
}
