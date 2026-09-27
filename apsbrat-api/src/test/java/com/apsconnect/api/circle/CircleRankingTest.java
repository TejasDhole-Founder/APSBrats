package com.apsconnect.api.circle;

import com.apsconnect.api.connection.Connection;
import com.apsconnect.api.connection.ConnectionStatus;
import com.apsconnect.api.user.User;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class CircleRankingTest {

    private final UUID vikram = UUID.randomUUID();
    private final UUID meera = UUID.randomUUID();
    private final UUID ananya = UUID.randomUUID();
    private final UUID ishita = UUID.randomUUID();

    @Test
    void mostMutualFirstThenSameBatchThenName() {
        List<UUID> ranked = CircleService.rankIds(
                List.of(ishita, ananya, meera, vikram),
                Map.of(vikram, 9, meera, 7, ananya, 7),
                Map.of(meera, true, ishita, true),
                Map.of(vikram, "vikram kumar", meera, "meera joshi", ananya, "ananya sethi", ishita, "ishita sharma"));

        // 9 mutual first; Meera and Ananya tie on 7 but Meera shares my batch; Ishita has none.
        assertThat(ranked).containsExactly(vikram, meera, ananya, ishita);
    }

    @Test
    void withoutMutualCountsItIsBatchThenAlphabetical() {
        List<UUID> ranked = CircleService.rankIds(
                List.of(vikram, ananya, ishita),
                Map.of(),
                Map.of(ishita, true),
                Map.of(vikram, "vikram kumar", ananya, "ananya sethi", ishita, "ishita sharma"));
        assertThat(ranked).containsExactly(ishita, ananya, vikram);
    }

    @Test
    void duplicatesCollapse() {
        List<UUID> ranked = CircleService.rankIds(List.of(vikram, vikram), Map.of(), Map.of(), Map.of(vikram, "v"));
        assertThat(ranked).containsExactly(vikram);
    }

    @Test
    void endingAConnectionPicksTheRightClosedStatus() {
        User requester = new User();
        requester.setId(vikram);
        User addressee = new User();
        addressee.setId(meera);
        Connection pending = new Connection();
        pending.setRequester(requester);
        pending.setAddressee(addressee);
        pending.setStatus(ConnectionStatus.PENDING);

        assertThat(com.apsconnect.api.connection.ConnectionServiceTestHook.closedStatus(pending, meera))
                .isEqualTo(ConnectionStatus.DECLINED);
        assertThat(com.apsconnect.api.connection.ConnectionServiceTestHook.closedStatus(pending, vikram))
                .isEqualTo(ConnectionStatus.WITHDRAWN);

        pending.setStatus(ConnectionStatus.ACCEPTED);
        assertThat(com.apsconnect.api.connection.ConnectionServiceTestHook.closedStatus(pending, vikram))
                .isEqualTo(ConnectionStatus.REMOVED);
    }
}
