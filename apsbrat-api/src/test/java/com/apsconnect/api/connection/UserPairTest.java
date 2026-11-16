package com.apsconnect.api.connection;

import org.junit.jupiter.api.Test;

import java.nio.ByteBuffer;
import java.util.Random;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class UserPairTest {

    /** How Postgres orders uuids: the 16 bytes as unsigned values, first byte first. */
    private static int postgresCompare(UUID a, UUID b) {
        byte[] x = bytes(a);
        byte[] y = bytes(b);
        for (int i = 0; i < 16; i++) {
            int c = Integer.compare(x[i] & 0xff, y[i] & 0xff);
            if (c != 0) {
                return c;
            }
        }
        return 0;
    }

    private static byte[] bytes(UUID id) {
        return ByteBuffer.allocate(16)
                .putLong(id.getMostSignificantBits())
                .putLong(id.getLeastSignificantBits())
                .array();
    }

    @Test
    void sameOrderForBothDirections() {
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();
        assertThat(UserPair.of(a, b)).isEqualTo(UserPair.of(b, a));
        assertThat(UserPair.of(a, b).lockKey()).isEqualTo(UserPair.of(b, a).lockKey());
    }

    @Test
    void orderMatchesPostgresNotJavaUuidCompareTo() {
        // Top bit set vs not: UUID.compareTo (signed) and Postgres (unsigned) disagree here.
        UUID big = new UUID(0x8000000000000000L, 0L);
        UUID small = new UUID(0x7fffffffffffffffL, 0L);
        assertThat(big.compareTo(small)).isNegative();
        assertThat(postgresCompare(big, small)).isPositive();

        UserPair pair = UserPair.of(big, small);
        assertThat(pair.low()).isEqualTo(small);
        assertThat(pair.high()).isEqualTo(big);
    }

    @Test
    void lowIsAlwaysTheSmallerUuidInPostgresOrder() {
        Random random = new Random(42);
        for (int i = 0; i < 20_000; i++) {
            UUID a = new UUID(random.nextLong(), random.nextLong());
            UUID b = new UUID(random.nextLong(), random.nextLong());
            UserPair pair = UserPair.of(a, b);
            assertThat(postgresCompare(pair.low(), pair.high())).isNegative();
        }
    }
}
