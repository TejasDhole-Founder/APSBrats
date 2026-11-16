package com.apsconnect.api.connection;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.safety.BlockService;
import com.apsconnect.api.user.PersonDto;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The relationship rules against a real Postgres: one row per pair, history, reverse requests,
 * blocking, mutual connections and simultaneous actions. Skipped without Docker.
 */
@SpringBootTest
@Testcontainers(disabledWithoutDocker = true)
class ConnectionFlowTest {

    @Container
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>(DockerImageName.parse("postgres:16"));

    @Container
    static final GenericContainer<?> REDIS =
            new GenericContainer<>(DockerImageName.parse("redis:7")).withExposedPorts(6379);

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.flyway.baseline-on-migrate", () -> "false");
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379).toString());
    }

    @Autowired ConnectionService service;
    @Autowired ConnectionQueryService queries;
    @Autowired BlockService blocks;
    @Autowired JdbcTemplate jdbc;

    // ── helpers ──────────────────────────────────────────────────────────

    private UUID user(String fullName) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO users (id, username, full_name, email) VALUES (?, ?, ?, ?)",
                id, "u" + id.toString().substring(0, 12), fullName, id + "@test.local");
        return id;
    }

    private void connect(UUID a, UUID b) {
        service.requestConnection(a, b);
        service.acceptConnection(b, a);
    }

    private List<ConnectionEventType> events(UUID a, UUID b) {
        return queries.history(a, b).stream().map(ConnectionEventDto::type).toList();
    }

    private int rows(UUID a, UUID b) {
        UserPair pair = UserPair.of(a, b);
        return jdbc.queryForObject(
                "SELECT COUNT(*) FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                Integer.class, pair.low(), pair.high());
    }

    private String status(UUID a, UUID b) {
        UserPair pair = UserPair.of(a, b);
        return jdbc.queryForObject(
                "SELECT status::text FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                String.class, pair.low(), pair.high());
    }

    private int notifications(UUID userId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE user_id = ?",
                Integer.class, userId);
    }

    private static HttpStatus statusOf(Throwable t) {
        return ((AppException) t).getStatus();
    }

    // ── relationship logic ───────────────────────────────────────────────

    @Test
    void requestThenAcceptConnectsBothAndRecordsHistory() {
        UUID arjun = user("Arjun");
        UUID rahul = user("Rahul");

        assertThat(service.requestConnection(arjun, rahul)).isEqualTo(ConnectionStatus.PENDING);
        assertThat(queries.statusWith(arjun, rahul)).isEqualTo("PENDING_OUT");
        assertThat(queries.statusWith(rahul, arjun)).isEqualTo("PENDING_IN");
        assertThat(queries.listPending(rahul)).extracting(PersonDto::id).containsExactly(arjun);
        assertThat(queries.listSent(arjun)).extracting(PersonDto::id).containsExactly(rahul);

        service.acceptConnection(rahul, arjun);

        assertThat(queries.statusWith(arjun, rahul)).isEqualTo("CONNECTED");
        assertThat(queries.listBatchmates(arjun)).extracting(PersonDto::id).containsExactly(rahul);
        assertThat(queries.listBatchmates(rahul)).extracting(PersonDto::id).containsExactly(arjun);
        assertThat(events(arjun, rahul))
                .containsExactly(ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED);
        assertThat(queries.history(rahul, arjun)).hasSize(2);
    }

    @Test
    void duplicateRequestIsRejectedAndMakesNoSecondRow() {
        UUID a = user("A");
        UUID b = user("B");
        service.requestConnection(a, b);

        assertThatThrownBy(() -> service.requestConnection(a, b))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.CONFLICT));
        assertThat(rows(a, b)).isEqualTo(1);
        assertThat(notifications(b)).isEqualTo(1);
    }

    @Test
    void requestWhileConnectedIsRejected() {
        UUID a = user("A");
        UUID b = user("B");
        connect(a, b);

        assertThatThrownBy(() -> service.requestConnection(b, a))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.CONFLICT));
        assertThat(rows(a, b)).isEqualTo(1);
    }

    @Test
    void cannotConnectWithYourself() {
        UUID a = user("A");
        assertThatThrownBy(() -> service.requestConnection(a, a))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.BAD_REQUEST));
    }

    @Test
    void reverseRequestAcceptsTheExistingOne() {
        UUID arjun = user("Arjun");
        UUID rahul = user("Rahul");
        service.requestConnection(arjun, rahul);

        ConnectionStatus result = service.requestConnection(rahul, arjun);

        assertThat(result).isEqualTo(ConnectionStatus.ACCEPTED);
        assertThat(rows(arjun, rahul)).isEqualTo(1);
        assertThat(status(arjun, rahul)).isEqualTo("ACCEPTED");
        assertThat(events(arjun, rahul)).containsExactly(
                ConnectionEventType.REQUESTED, ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED);
        // Arjun is told Rahul accepted; Rahul got the original request.
        assertThat(notifications(arjun)).isEqualTo(1);
        assertThat(notifications(rahul)).isEqualTo(1);
    }

    @Test
    void declineWithdrawAndRemoveEachLeaveTheirOwnStatus() {
        UUID a = user("A");
        UUID b = user("B");
        UUID c = user("C");

        service.requestConnection(a, b);
        assertThat(service.endConnection(b, a)).isEqualTo(ConnectionStatus.DECLINED);

        service.requestConnection(a, c);
        assertThat(service.endConnection(a, c)).isEqualTo(ConnectionStatus.WITHDRAWN);

        connect(a, b);
        assertThat(service.endConnection(a, b)).isEqualTo(ConnectionStatus.REMOVED);

        assertThat(events(a, b)).containsExactly(
                ConnectionEventType.REQUESTED, ConnectionEventType.DECLINED,
                ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED, ConnectionEventType.REMOVED);
        assertThat(events(a, c)).containsExactly(ConnectionEventType.REQUESTED, ConnectionEventType.WITHDRAWN);
        assertThat(queries.statusWith(a, b)).isEqualTo("NONE");
        assertThat(queries.listBatchmates(a)).isEmpty();
    }

    @Test
    void endingWithNothingLiveIs404() {
        UUID a = user("A");
        UUID b = user("B");
        assertThatThrownBy(() -> service.endConnection(a, b))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));
    }

    @Test
    void reconnectReusesTheRowAndKeepsCreatedAtAndHistory() {
        UUID a = user("A");
        UUID b = user("B");
        connect(a, b);
        Timestamp created = jdbc.queryForObject(
                "SELECT created_at FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                Timestamp.class, UserPair.of(a, b).low(), UserPair.of(a, b).high());
        UUID rowId = jdbc.queryForObject("SELECT id FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                UUID.class, UserPair.of(a, b).low(), UserPair.of(a, b).high());
        service.endConnection(a, b);

        // The other person asks this time.
        assertThat(service.requestConnection(b, a)).isEqualTo(ConnectionStatus.PENDING);

        assertThat(rows(a, b)).isEqualTo(1);
        UserPair pair = UserPair.of(a, b);
        assertThat(jdbc.queryForObject("SELECT id FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                UUID.class, pair.low(), pair.high())).isEqualTo(rowId);
        assertThat(jdbc.queryForObject("SELECT created_at FROM connections WHERE user_low_id = ? AND user_high_id = ?",
                Timestamp.class, pair.low(), pair.high())).isEqualTo(created);
        assertThat(jdbc.queryForObject("SELECT requested_at > created_at FROM connections WHERE id = ?",
                Boolean.class, rowId)).isTrue();
        assertThat(jdbc.queryForObject("SELECT accepted_at IS NULL FROM connections WHERE id = ?",
                Boolean.class, rowId)).isTrue();
        assertThat(queries.statusWith(b, a)).isEqualTo("PENDING_OUT");
        assertThat(events(a, b)).containsExactly(
                ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED,
                ConnectionEventType.REMOVED, ConnectionEventType.REQUESTED);
    }

    // ── security ─────────────────────────────────────────────────────────

    @Test
    void onlyTheRecipientCanAccept() {
        UUID a = user("A");
        UUID b = user("B");
        service.requestConnection(a, b);

        assertThatThrownBy(() -> service.acceptConnection(a, b))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.FORBIDDEN));
        assertThat(status(a, b)).isEqualTo("PENDING");
    }

    @Test
    void aStrangerCannotTouchSomeoneElsesRelationship() {
        UUID a = user("A");
        UUID b = user("B");
        UUID stranger = user("Stranger");
        service.requestConnection(a, b);

        // The pair is always (me, other), so the stranger only ever reaches their own pairs.
        assertThatThrownBy(() -> service.acceptConnection(stranger, a))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));
        assertThatThrownBy(() -> service.endConnection(stranger, b))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));
        assertThatThrownBy(() -> queries.history(stranger, a))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));
        assertThat(status(a, b)).isEqualTo("PENDING");
    }

    @Test
    void acceptingAnAlreadyAcceptedConnectionChangesNothing() {
        UUID a = user("A");
        UUID b = user("B");
        connect(a, b);
        int before = notifications(a);

        service.acceptConnection(b, a);

        assertThat(events(a, b)).containsExactly(ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED);
        assertThat(notifications(a)).isEqualTo(before);
    }

    // ── blocking ─────────────────────────────────────────────────────────

    @Test
    void blockedPeopleCannotRequestInEitherDirection() {
        UUID blocker = user("Blocker");
        UUID blocked = user("Blocked");
        blocks.block(blocker, blocked);

        assertThatThrownBy(() -> service.requestConnection(blocker, blocked))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));
        assertThatThrownBy(() -> service.requestConnection(blocked, blocker))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));
        assertThat(rows(blocker, blocked)).isZero();
        // Who blocked whom is stored on the block, not mixed into connections.
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?",
                Integer.class, blocker, blocked)).isEqualTo(1);
    }

    @Test
    void blockingEndsTheConnectionAndRecordsWhoDidIt() {
        UUID blocker = user("Blocker");
        UUID blocked = user("Blocked");
        connect(blocker, blocked);

        blocks.block(blocker, blocked);

        assertThat(status(blocker, blocked)).isEqualTo("REMOVED");
        assertThat(queries.statusWith(blocked, blocker)).isEqualTo("NONE");
        List<ConnectionEventDto> history = queries.history(blocked, blocker);
        assertThat(history).extracting(ConnectionEventDto::type).containsExactly(
                ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED, ConnectionEventType.REMOVED);
        assertThat(history.get(2).actorId()).isEqualTo(blocker);
        // The reason is kept for staff only.
        assertThat(jdbc.queryForObject(
                "SELECT metadata->>'reason' FROM connection_events WHERE connection_id IN "
                        + "(SELECT id FROM connections WHERE user_low_id = ? AND user_high_id = ?) "
                        + "AND event_type = 'REMOVED'",
                String.class, UserPair.of(blocker, blocked).low(), UserPair.of(blocker, blocked).high()))
                .isEqualTo("BLOCK");
    }

    // ── notifications ────────────────────────────────────────────────────

    @Test
    void aFailedRequestLeavesNoNotificationAndNoRow() {
        UUID a = user("A");
        UUID missing = UUID.randomUUID();

        assertThatThrownBy(() -> service.requestConnection(a, missing))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.NOT_FOUND));

        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM connections WHERE requester_id = ?", Integer.class, a)).isZero();
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM notifications WHERE actor_id = ?", Integer.class, a)).isZero();
    }

    // ── mutual connections ───────────────────────────────────────────────

    @Test
    void mutualConnectionsCountOnlyAcceptedAndNeverStoreAList() {
        UUID me = user("Me");
        UUID other = user("Other");
        assertThat(queries.mutualCount(me, other)).isZero();

        UUID one = user("One");
        connect(me, one);
        assertThat(queries.mutualCount(me, other)).isZero();   // only me knows them
        connect(one, other);                                   // direction differs from the line above
        assertThat(queries.mutualCount(me, other)).isEqualTo(1);
        assertThat(queries.mutualCount(other, me)).isEqualTo(1);

        UUID two = user("Two");
        UUID three = user("Three");
        connect(two, me);
        connect(other, two);
        connect(me, three);
        connect(three, other);
        assertThat(queries.mutualCount(me, other)).isEqualTo(3);

        // Pending does not count.
        UUID pending = user("Pending");
        connect(me, pending);
        service.requestConnection(pending, other);
        assertThat(queries.mutualCount(me, other)).isEqualTo(3);

        // Removed does not count.
        UUID removed = user("Removed");
        connect(me, removed);
        connect(removed, other);
        assertThat(queries.mutualCount(me, other)).isEqualTo(4);
        service.endConnection(other, removed);
        assertThat(queries.mutualCount(me, other)).isEqualTo(3);

        // Someone only I know is not mutual.
        connect(me, user("Solo"));
        assertThat(queries.mutualCount(me, other)).isEqualTo(3);
        assertThat(queries.listMutual(me, other)).hasSize(3);
    }

    @Test
    void mutualAndConnectionListsPageInStableOrderWithoutRepeats() {
        UUID me = user("Me");
        UUID other = user("Other");
        List<UUID> commons = new ArrayList<>();
        for (int i = 1; i <= 5; i++) {
            UUID c = user("Common " + i);
            commons.add(c);
            if (i % 2 == 0) {
                connect(me, c);
                connect(c, other);
            } else {
                connect(c, me);
                connect(other, c);
            }
        }
        // Two people with the same name still page without loss or repeats.
        UUID twinA = user("Common 3");
        UUID twinB = user("Common 3");
        commons.add(twinA);
        commons.add(twinB);
        for (UUID twin : List.of(twinA, twinB)) {
            connect(me, twin);
            connect(twin, other);
        }

        List<UUID> seen = new ArrayList<>();
        String cursor = null;
        int pages = 0;
        do {
            CursorPage<PersonDto> page = queries.pageMutual(me, other, cursor, 3);
            page.items().forEach(p -> seen.add(p.id()));
            cursor = page.nextCursor();
            pages++;
            assertThat(page.hasMore()).isEqualTo(cursor != null);
        } while (cursor != null && pages < 10);

        assertThat(pages).isEqualTo(3);
        assertThat(seen).hasSize(7).doesNotHaveDuplicates().containsExactlyInAnyOrderElementsOf(commons);
        // A to Z by name.
        List<String> names = seen.stream()
                .map(id -> jdbc.queryForObject("SELECT full_name FROM users WHERE id = ?", String.class, id))
                .toList();
        assertThat(names).isSorted();

        // The same cursor again returns the same page.
        CursorPage<PersonDto> first = queries.pageMutual(me, other, null, 3);
        assertThat(queries.pageMutual(me, other, null, 3).items()).extracting(PersonDto::id)
                .containsExactlyElementsOf(first.items().stream().map(PersonDto::id).toList());

        // My own connection list pages the same way (the 7 commons plus nobody else).
        Set<UUID> mine = new HashSet<>();
        String next = null;
        do {
            CursorPage<PersonDto> page = queries.pageConnections(me, next, 2);
            page.items().forEach(p -> mine.add(p.id()));
            next = page.nextCursor();
        } while (next != null);
        assertThat(mine).containsExactlyInAnyOrderElementsOf(commons);
    }

    @Test
    void aBadCursorIsRejected() {
        UUID me = user("Me");
        assertThatThrownBy(() -> queries.pageConnections(me, "not-a-cursor", 10))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.BAD_REQUEST));
    }

    // ── concurrency ──────────────────────────────────────────────────────

    /** Runs the tasks at the same instant, each on its own thread and transaction. */
    private List<Object> race(List<? extends Callable<?>> tasks) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(tasks.size());
        try {
            CyclicBarrier start = new CyclicBarrier(tasks.size());
            List<Future<Object>> futures = new ArrayList<>();
            for (Callable<?> task : tasks) {
                futures.add(pool.submit(() -> {
                    start.await();
                    try {
                        return task.call();
                    } catch (Throwable t) {
                        return t;
                    }
                }));
            }
            List<Object> results = new ArrayList<>();
            for (Future<Object> f : futures) {
                results.add(f.get());
            }
            return results;
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void oppositeRequestsAtTheSameTimeMakeOneConnectedRow() throws Exception {
        for (int round = 0; round < 15; round++) {
            UUID a = user("A" + round);
            UUID b = user("B" + round);

            List<Object> results = race(List.of(
                    () -> service.requestConnection(a, b),
                    () -> service.requestConnection(b, a)));

            assertThat(results).noneMatch(r -> r instanceof Throwable);
            assertThat(rows(a, b)).as("round %d", round).isEqualTo(1);
            assertThat(status(a, b)).isEqualTo("ACCEPTED");
            assertThat(events(a, b)).containsExactlyInAnyOrder(
                    ConnectionEventType.REQUESTED, ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED);
            // Exactly one of them ended up PENDING-then-accepted: one was told, one was asked.
            assertThat(notifications(a) + notifications(b)).isEqualTo(2);
        }
    }

    @Test
    void theSameRequestSentTwiceAtOnceSucceedsOnceAndConflictsOnce() throws Exception {
        for (int round = 0; round < 10; round++) {
            UUID a = user("A" + round);
            UUID b = user("B" + round);

            List<Object> results = race(List.of(
                    () -> service.requestConnection(a, b),
                    () -> service.requestConnection(a, b)));

            long ok = results.stream().filter(r -> r == ConnectionStatus.PENDING).count();
            long conflict = results.stream()
                    .filter(r -> r instanceof AppException e && e.getStatus() == HttpStatus.CONFLICT).count();
            assertThat(ok).isEqualTo(1);
            assertThat(conflict).isEqualTo(1);
            assertThat(rows(a, b)).isEqualTo(1);
            assertThat(notifications(b)).isEqualTo(1);
        }
    }

    @Test
    void twoSimultaneousAcceptsAcceptOnce() throws Exception {
        for (int round = 0; round < 10; round++) {
            UUID a = user("A" + round);
            UUID b = user("B" + round);
            service.requestConnection(a, b);

            List<Object> results = race(List.of(
                    () -> { service.acceptConnection(b, a); return "ok"; },
                    () -> { service.acceptConnection(b, a); return "ok"; }));

            assertThat(results).containsOnly("ok");
            assertThat(events(a, b)).containsExactly(
                    ConnectionEventType.REQUESTED, ConnectionEventType.ACCEPTED);
            assertThat(notifications(a)).isEqualTo(1);
        }
    }

    @Test
    void acceptAndWithdrawAtTheSameTimeEndInOneConsistentState() throws Exception {
        for (int round = 0; round < 10; round++) {
            UUID a = user("A" + round);
            UUID b = user("B" + round);
            service.requestConnection(a, b);

            race(List.of(
                    () -> { service.acceptConnection(b, a); return "accepted"; },
                    () -> service.endConnection(a, b)));

            // Either order is valid: accepted then removed, or withdrawn (the accept then finds nothing).
            assertThat(rows(a, b)).isEqualTo(1);
            assertThat(status(a, b)).isIn("REMOVED", "WITHDRAWN");
            assertThat(queries.statusWith(a, b)).isEqualTo("NONE");
        }
    }

    @Test
    void aRequestAndABlockAtTheSameTimeNeverLeaveALiveConnection() throws Exception {
        for (int round = 0; round < 15; round++) {
            UUID requester = user("R" + round);
            UUID blocker = user("B" + round);

            race(List.of(
                    () -> service.requestConnection(requester, blocker),
                    () -> { blocks.block(blocker, requester); return "blocked"; }));

            assertThat(jdbc.queryForObject(
                    "SELECT COUNT(*) FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?",
                    Integer.class, blocker, requester)).isEqualTo(1);
            assertThat(queries.statusWith(requester, blocker)).as("round %d", round).isEqualTo("NONE");
            assertThat(rows(requester, blocker)).isLessThanOrEqualTo(1);
        }
    }

    @Test
    void manyPeopleRequestingEachOtherAtOnceNeverBreakTheOneRowRule() throws Exception {
        List<UUID> people = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            people.add(user("P" + i));
        }
        List<Callable<ConnectionStatus>> tasks = new ArrayList<>();
        for (UUID from : people) {
            for (UUID to : people) {
                if (!from.equals(to)) {
                    tasks.add(() -> service.requestConnection(from, to));
                }
            }
        }
        List<Object> results = race(tasks);

        // Every outcome is a normal answer (done or "already exists"), never a crash.
        assertThat(results).allMatch(r -> r instanceof ConnectionStatus
                || (r instanceof AppException e && e.getStatus() == HttpStatus.CONFLICT));
        for (UUID a : people) {
            for (UUID b : people) {
                if (a.compareTo(b) < 0) {
                    assertThat(rows(a, b)).isEqualTo(1);
                    assertThat(status(a, b)).isEqualTo("ACCEPTED");
                }
            }
        }
    }

    // ── database rules ───────────────────────────────────────────────────

    @Test
    void theDatabaseItselfRefusesASecondRowForTheSamePair() {
        UUID a = user("A");
        UUID b = user("B");
        service.requestConnection(a, b);
        UserPair pair = UserPair.of(a, b);

        // Same pair, opposite direction, bypassing the service.
        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO connections (requester_id, addressee_id, user_low_id, user_high_id, status, created_at) "
                        + "VALUES (?, ?, ?, ?, 'PENDING', now())",
                b, a, pair.low(), pair.high()))
                .hasMessageContaining("uq_connection_pair");
    }

    @Test
    void theDatabaseRefusesAWronglyOrderedPairAndSelfConnections() {
        UUID a = user("A");
        UUID b = user("B");
        UserPair pair = UserPair.of(a, b);

        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO connections (requester_id, addressee_id, user_low_id, user_high_id, status) "
                        + "VALUES (?, ?, ?, ?, 'PENDING')",
                a, b, pair.high(), pair.low()))
                .hasMessageContaining("chk_connection_pair_order");
        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO connections (requester_id, addressee_id, user_low_id, user_high_id, status) "
                        + "VALUES (?, ?, ?, ?, 'PENDING')",
                a, a, a, a))
                .isInstanceOf(Exception.class);
    }

    @Test
    void theIndexesTheQueriesRelyOnExist() {
        List<String> indexes = jdbc.queryForList(
                "SELECT indexname FROM pg_indexes WHERE tablename IN ('connections', 'connection_events')",
                String.class);
        assertThat(indexes).contains(
                "uq_connection_pair",                 // pair lookup: status, request, accept, end, history
                "idx_conn_pending_incoming",          // received requests, newest first
                "idx_conn_pending_outgoing",          // sent requests, newest first
                "idx_conn_requester_status", "idx_conn_addressee_status",
                "idx_conn_requester_accepted", "idx_conn_addressee_accepted",
                "idx_conn_events_connection_created");
    }

    // ── paged request lists ──────────────────────────────────────────────

    private static <T> List<T> reversed(List<T> list) {
        List<T> copy = new ArrayList<>(list);
        java.util.Collections.reverse(copy);
        return copy;
    }

    private List<UUID> allPages(java.util.function.BiFunction<String, Integer, CursorPage<PersonDto>> fetch, int size) {
        List<UUID> seen = new ArrayList<>();
        String cursor = null;
        int guard = 0;
        do {
            CursorPage<PersonDto> page = fetch.apply(cursor, size);
            page.items().forEach(p -> seen.add(p.id()));
            cursor = page.nextCursor();
            assertThat(page.hasMore()).isEqualTo(cursor != null);
        } while (cursor != null && ++guard < 50);
        return seen;
    }

    @Test
    void receivedAndSentRequestsPageNewestFirstAndMatchTheFullLists() {
        UUID me = user("Me");
        List<UUID> senders = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            UUID s = user("Sender " + i);
            senders.add(s);
            service.requestConnection(s, me);
        }
        List<UUID> targets = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            UUID t = user("Target " + i);
            targets.add(t);
            service.requestConnection(me, t);
        }

        // Newest first: the last request sent is the first one shown.
        List<UUID> received = allPages((c, n) -> queries.pageReceived(me, c, n), 3);
        assertThat(received).containsExactlyElementsOf(reversed(senders));
        List<UUID> sent = allPages((c, n) -> queries.pageSent(me, c, n), 2);
        assertThat(sent).containsExactlyElementsOf(reversed(targets));

        // The same people the full lists return.
        assertThat(queries.listPending(me)).extracting(PersonDto::id).containsExactlyInAnyOrderElementsOf(received);
        assertThat(queries.listSent(me)).extracting(PersonDto::id).containsExactlyInAnyOrderElementsOf(sent);

        // First page repeats exactly; the page format matches the other lists (items, nextCursor, hasMore).
        CursorPage<PersonDto> first = queries.pageReceived(me, null, 3);
        assertThat(first.items()).hasSize(3);
        assertThat(first.hasMore()).isTrue();
        assertThat(queries.pageReceived(me, null, 3).items()).extracting(PersonDto::id)
                .containsExactlyElementsOf(first.items().stream().map(PersonDto::id).toList());
    }

    @Test
    void answeredRequestsLeaveThePagedListsAndTiesStillPageWithoutLoss() {
        UUID me = user("Me");
        List<UUID> senders = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            UUID s = user("Sender " + i);
            senders.add(s);
            service.requestConnection(s, me);
        }
        // Make four of them share the exact same request time: the id has to break the tie.
        jdbc.update("UPDATE connections SET requested_at = TIMESTAMP '2030-01-01 10:00:00' "
                + "WHERE addressee_id = ? AND requester_id IN (?, ?, ?, ?)",
                me, senders.get(0), senders.get(1), senders.get(2), senders.get(3));

        assertThat(allPages((c, n) -> queries.pageReceived(me, c, n), 2))
                .hasSize(6).doesNotHaveDuplicates().containsExactlyInAnyOrderElementsOf(senders);

        service.acceptConnection(me, senders.get(0));     // answered: no longer waiting
        service.endConnection(me, senders.get(1));        // declined
        jdbc.update("UPDATE users SET deleted_at = now() WHERE id = ?", senders.get(2)); // closed account

        assertThat(allPages((c, n) -> queries.pageReceived(me, c, n), 2))
                .hasSize(3).containsExactlyInAnyOrder(senders.get(3), senders.get(4), senders.get(5));
        assertThat(allPages((c, n) -> queries.pageSent(me, c, n), 2)).isEmpty();
    }

    @Test
    void aBadRequestsCursorIsRejected() {
        UUID me = user("Me");
        assertThatThrownBy(() -> queries.pageReceived(me, "not-a-cursor", 10))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.BAD_REQUEST));
        // A cursor that decodes but carries something other than a time (e.g. one from the A-to-Z lists).
        String nameCursor = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
                (UUID.randomUUID() + "|some name").getBytes(java.nio.charset.StandardCharsets.UTF_8));
        assertThatThrownBy(() -> queries.pageSent(me, nameCursor, 10))
                .satisfies(e -> assertThat(statusOf(e)).isEqualTo(HttpStatus.BAD_REQUEST));
    }
}
