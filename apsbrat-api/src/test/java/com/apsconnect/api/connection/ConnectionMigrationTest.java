package com.apsconnect.api.connection;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V39 on data written by the old code: the schema is built up to V38, old-style rows are
 * inserted (including a pair stored twice, once per direction), then V39 runs. Skipped without Docker.
 */
@Testcontainers(disabledWithoutDocker = true)
class ConnectionMigrationTest {

    @Container
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>(DockerImageName.parse("postgres:16"));

    private static Flyway flyway(String target) {
        return Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .locations("classpath:db/migration")
                .target(target)
                .load();
    }

    private static Connection db() throws SQLException {
        return DriverManager.getConnection(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
    }

    private static void exec(Connection c, String sql, Object... args) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < args.length; i++) {
                ps.setObject(i + 1, args[i]);
            }
            ps.executeUpdate();
        }
    }

    private static List<String> column(Connection c, String sql, Object... args) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < args.length; i++) {
                ps.setObject(i + 1, args[i]);
            }
            List<String> out = new ArrayList<>();
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    out.add(rs.getString(1));
                }
            }
            return out;
        }
    }

    private static UUID legacy(Connection c, UUID requester, UUID addressee, String status,
                               String createdAt, String acceptedAt) throws SQLException {
        UUID id = UUID.randomUUID();
        exec(c, "INSERT INTO connections (id, requester_id, addressee_id, status, created_at, accepted_at, updated_at) "
                        + "VALUES (?, ?, ?, ?::connection_status, ?::timestamp, ?::timestamp, ?::timestamp)",
                id, requester, addressee, status, createdAt, acceptedAt, acceptedAt != null ? acceptedAt : createdAt);
        return id;
    }

    @Test
    void oldRowsGetPairsHistoryAndOnePerPair() throws Exception {
        flyway("38").migrate();

        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();
        UUID c2 = UUID.randomUUID();
        UUID d = UUID.randomUUID();
        UUID e = UUID.randomUUID();
        UUID f = UUID.randomUUID();
        UUID g = UUID.randomUUID();
        UUID h = UUID.randomUUID();
        UUID i = UUID.randomUUID();
        UUID bothPendingOlder;
        UUID bothPendingNewer;
        UUID declinedThenWithdrawnA;
        UUID declinedThenWithdrawnB;
        UUID acceptedRow;
        UUID reversePendingRow;
        UUID withdrawnRow;
        UUID declinedRow;
        UUID removedRow;
        UUID pendingRow;

        try (Connection c = db()) {
            for (UUID id : List.of(a, b, c2, d, e)) {
                exec(c, "INSERT INTO users (id, username, full_name, email) VALUES (?, ?, 'U', ?)",
                        id, "m" + id.toString().substring(0, 12), id + "@test.local");
            }
            // Pair a-b stored twice by an old race: a accepted (b's answer), and b's own request, pending.
            acceptedRow = legacy(c, a, b, "ACCEPTED", "2025-01-10 10:00:00", "2025-01-11 09:00:00");
            reversePendingRow = legacy(c, b, a, "PENDING", "2025-01-05 08:00:00", null);
            exec(c, "INSERT INTO notifications (user_id, type, title, ref_type, ref_id) "
                            + "VALUES (?, 'CONNECTION_REQUEST'::notification_type, 'wants to connect', 'CONNECTION', ?)",
                    a, reversePendingRow);

            withdrawnRow = legacy(c, c2, d, "WITHDRAWN", "2025-02-01 10:00:00", null);
            declinedRow = legacy(c, d, b, "DECLINED", "2025-02-02 10:00:00", null);
            removedRow = legacy(c, c2, e, "REMOVED", "2025-02-03 10:00:00", "2025-02-04 10:00:00");
            pendingRow = legacy(c, e, d, "PENDING", "2025-02-05 10:00:00", null);

            // Two more pairs stored twice: both asking each other at once, and a decline next to a withdrawal.
            for (UUID id : List.of(f, g, h, i)) {
                exec(c, "INSERT INTO users (id, username, full_name, email) VALUES (?, ?, 'U', ?)",
                        id, "m" + id.toString().substring(0, 12), id + "@test.local");
            }
            bothPendingOlder = legacy(c, f, g, "PENDING", "2025-03-01 10:00:00", null);
            bothPendingNewer = legacy(c, g, f, "PENDING", "2025-03-02 10:00:00", null);
            exec(c, "INSERT INTO notifications (user_id, type, title, ref_type, ref_id) "
                            + "VALUES (?, 'CONNECTION_REQUEST'::notification_type, 'wants to connect', 'CONNECTION', ?)",
                    g, bothPendingOlder);
            exec(c, "INSERT INTO notifications (user_id, type, title, ref_type, ref_id) "
                            + "VALUES (?, 'CONNECTION_REQUEST'::notification_type, 'wants to connect', 'CONNECTION', ?)",
                    f, bothPendingNewer);
            declinedThenWithdrawnA = legacy(c, h, i, "DECLINED", "2025-04-01 10:00:00", null);
            declinedThenWithdrawnB = legacy(c, i, h, "WITHDRAWN", "2025-04-02 10:00:00", null);
        }

        flyway("39").migrate();

        try (Connection c = db()) {
            // One row per pair: the duplicate pair collapsed, nothing else lost.
            // (The demo seed from V14 has connections of its own, so count only this test's people.)
            String mine = "'" + a + "','" + b + "','" + c2 + "','" + d + "','" + e
                    + "','" + f + "','" + g + "','" + h + "','" + i + "'";
            assertThat(column(c, "SELECT COUNT(*)::text FROM connections WHERE requester_id IN (" + mine + ")"))
                    .containsExactly("7");

            // Both pending: the newer row is kept, both people's notifications now point at it, the earlier
            // created_at survives, and both requests are in the history.
            UserPair fg = UserPair.of(f, g);
            assertThat(column(c, "SELECT id::text FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                    fg.low(), fg.high())).containsExactly(bothPendingNewer.toString());
            assertThat(column(c, "SELECT status::text FROM connections WHERE id = ?", bothPendingNewer))
                    .containsExactly("PENDING");
            assertThat(column(c, "SELECT to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') FROM connections WHERE id = ?",
                    bothPendingNewer)).containsExactly("2025-03-01 10:00:00");
            assertThat(column(c, "SELECT COUNT(*)::text FROM notifications WHERE ref_id = ?", bothPendingNewer))
                    .containsExactly("2");
            assertThat(column(c, "SELECT COUNT(*)::text FROM notifications WHERE ref_id = ?", bothPendingOlder))
                    .containsExactly("0");
            assertThat(column(c, "SELECT event_type || ':' || actor_id FROM connection_events WHERE connection_id = ? "
                    + "ORDER BY actor_id::text", bothPendingNewer))
                    .containsExactlyInAnyOrder("REQUESTED:" + f, "REQUESTED:" + g);

            // Decline next to a withdrawal: the later one is kept; both endings stay in the history.
            UserPair hi = UserPair.of(h, i);
            assertThat(column(c, "SELECT id::text FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                    hi.low(), hi.high())).containsExactly(declinedThenWithdrawnB.toString());
            assertThat(column(c, "SELECT status::text FROM connections WHERE id = ?", declinedThenWithdrawnB))
                    .containsExactly("WITHDRAWN");
            assertThat(column(c, "SELECT event_type || ':' || actor_id FROM connection_events WHERE connection_id = ?",
                    declinedThenWithdrawnB))
                    .containsExactlyInAnyOrder("REQUESTED:" + h, "REQUESTED:" + i, "DECLINED:" + i, "WITHDRAWN:" + i);
            assertThat(column(c, "SELECT COUNT(*)::text FROM connection_events WHERE connection_id = ?",
                    declinedThenWithdrawnA)).containsExactly("0");
            assertThat(column(c, "SELECT COUNT(*)::text FROM connections WHERE user_low_id >= user_high_id"))
                    .containsExactly("0");
            assertThat(column(c, "SELECT COUNT(*)::text FROM connections WHERE requested_at IS NULL"))
                    .containsExactly("0");

            // The pair a-b kept the accepted row, the earliest created_at, and its notification link.
            UserPair ab = UserPair.of(a, b);
            assertThat(column(c, "SELECT id::text FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                    ab.low(), ab.high())).containsExactly(acceptedRow.toString());
            assertThat(column(c, "SELECT status::text FROM connections WHERE id = ?", acceptedRow))
                    .containsExactly("ACCEPTED");
            assertThat(column(c, "SELECT to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') FROM connections WHERE id = ?",
                    acceptedRow)).containsExactly("2025-01-05 08:00:00");
            assertThat(column(c, "SELECT ref_id::text FROM notifications WHERE user_id = ? AND ref_type = 'CONNECTION'", a))
                    .containsExactly(acceptedRow.toString());

            // History: both people's requests and the acceptance; the moved one says where it came from.
            assertThat(column(c, "SELECT event_type FROM connection_events WHERE connection_id = ? "
                    + "ORDER BY created_at, event_type", acceptedRow))
                    .containsExactly("REQUESTED", "REQUESTED", "ACCEPTED");
            assertThat(column(c, "SELECT metadata->>'mergedFrom' FROM connection_events "
                    + "WHERE connection_id = ? AND metadata->>'mergedFrom' IS NOT NULL", acceptedRow))
                    .containsExactly(reversePendingRow.toString());

            // Closed rows keep how they ended, with the person who did it when that is known.
            assertThat(column(c, "SELECT event_type || ':' || COALESCE(actor_id::text, '-') FROM connection_events "
                    + "WHERE connection_id = ? ORDER BY created_at, event_type", withdrawnRow))
                    .containsExactly("REQUESTED:" + c2, "WITHDRAWN:" + c2);
            assertThat(column(c, "SELECT event_type || ':' || COALESCE(actor_id::text, '-') FROM connection_events "
                    + "WHERE connection_id = ? ORDER BY created_at, event_type", declinedRow))
                    .containsExactly("REQUESTED:" + d, "DECLINED:" + b);
            assertThat(column(c, "SELECT event_type || ':' || COALESCE(actor_id::text, '-') FROM connection_events "
                    + "WHERE connection_id = ? ORDER BY created_at, event_type", removedRow))
                    .containsExactly("REQUESTED:" + c2, "ACCEPTED:" + e, "REMOVED:-");
            assertThat(column(c, "SELECT event_type FROM connection_events WHERE connection_id = ?", pendingRow))
                    .containsExactly("REQUESTED");

            // The rules are now in the database.
            UserPair pair = UserPair.of(c2, d);
            assertThatThrownBy(() -> exec(c,
                    "INSERT INTO connections (requester_id, addressee_id, user_low_id, user_high_id, status) "
                            + "VALUES (?, ?, ?, ?, 'PENDING')", d, c2, pair.low(), pair.high()))
                    .hasMessageContaining("uq_connection_pair");

            // Indexes: the old single-column ones and the per-direction key are gone, the new ones exist.
            assertThat(column(c, "SELECT indexname FROM pg_indexes WHERE tablename = 'connections' ORDER BY 1"))
                    .contains("uq_connection_pair", "idx_conn_requester_status", "idx_conn_addressee_status",
                            "idx_conn_requester_accepted", "idx_conn_addressee_accepted")
                    .doesNotContain("idx_conn_requester", "idx_conn_addressee", "uq_connection");
        }
    }
}
