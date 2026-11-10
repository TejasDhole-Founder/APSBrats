package com.apsconnect.api.career;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class NameKeysTest {
    @Test
    void spellingVariantsShareOneKey() {
        assertThat(NameKeys.of("Zomato Pvt. Ltd.")).isEqualTo("zomato");
        assertThat(NameKeys.of("  ZOMATO ")).isEqualTo("zomato");
        assertThat(NameKeys.of("Tata Consultancy Services Limited")).isEqualTo("tata consultancy services");
    }

    @Test
    void keepsNamesThatAreOnlyALegalWord() {
        assertThat(NameKeys.of("Co")).isEqualTo("co");
        assertThat(NameKeys.of(null)).isEmpty();
    }
}