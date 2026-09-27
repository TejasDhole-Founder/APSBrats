package com.apsconnect.api.search;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;

class PeopleSearchTokensTest {

    private static boolean matches(String haystack, String... words) {
        String pattern = PeopleSearchService.wordPrefixPattern(List.of(words));
        // Java's regex lookahead semantics match Postgres ARE for these patterns.
        return Pattern.compile(pattern).matcher(haystack.toLowerCase()).find();
    }

    @Test
    void splitsAndNormalisesTheQuery() {
        assertThat(PeopleSearchService.normalize("  Amit   Pra ")).isEqualTo("amit pra");
        assertThat(PeopleSearchService.tokens("amit pra")).containsExactly("amit", "pra");
        assertThat(PeopleSearchService.tokens("seed.amit_das")).containsExactly("seed", "amit", "das");
        assertThat(PeopleSearchService.tokens("")).isEmpty();
    }

    @Test
    void everyWordMustStartAWordOfNameOrUsername() {
        assertThat(matches("Amit Prasad amit.prasad", "amit", "pra")).isTrue();
        assertThat(matches("Amit Prasad amit.prasad", "pra", "amit")).isTrue();
        assertThat(matches("Sumit Prakash sumit.p", "amit")).isFalse();
        assertThat(matches("Amit Das seed.amit.das.15", "das", "15")).isTrue();
        assertThat(matches("Amit Das seed.amit.das.15", "amit", "pra")).isFalse();
    }

    @Test
    void regexSpecialCharactersAreEscaped() {
        assertThat(matches("Amit Prasad amit.prasad", "a.i")).isFalse();
        assertThat(matches("Amit (Prasad) amit", "(pra")).isTrue();
    }
}
