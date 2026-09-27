package com.apsconnect.api.user.history;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SchoolHistoryOverlapTest {

    private static SaveSchoolHistoryItemRequest item(int classFrom, int classTo, int start, int end) {
        return new SaveSchoolHistoryItemRequest(UUID.randomUUID(), (short) classFrom, (short) classTo, "A",
                (short) start, (short) end, classTo >= 11 ? Stream.COMMERCE : null, false);
    }

    @Test
    void adjacentSchoolsSharingTheBoundaryYearAreFine() {
        String problem = UserSchoolHistoryService.overlapProblem(List.of(
                item(6, 9, 2015, 2019),
                item(10, 12, 2019, 2022)));
        assertThat(problem).isNull();
    }

    @Test
    void rejectsOverlappingYears() {
        String problem = UserSchoolHistoryService.overlapProblem(List.of(
                item(8, 9, 2018, 2020),
                item(10, 12, 2019, 2021)));
        assertThat(problem).contains("overlap in years");
    }

    @Test
    void rejectsOverlappingClasses() {
        String problem = UserSchoolHistoryService.overlapProblem(List.of(
                item(8, 10, 2016, 2019),
                item(10, 12, 2019, 2022)));
        assertThat(problem).contains("overlap in classes");
    }

    @Test
    void rejectsLowerClassesAfterHigherClasses() {
        String problem = UserSchoolHistoryService.overlapProblem(List.of(
                item(10, 12, 2015, 2018),
                item(6, 9, 2019, 2022)));
        assertThat(problem).contains("out of order");
    }

    @Test
    void streamRequiredFromClassEleven() {
        SaveSchoolHistoryItemRequest noStream = new SaveSchoolHistoryItemRequest(UUID.randomUUID(), (short) 10,
                (short) 12, "A", (short) 2019, (short) 2022, null, false);
        assertThat(UserSchoolHistoryService.streamProblem(noStream)).contains("required");
    }

    @Test
    void streamNotAllowedBelowClassEleven() {
        SaveSchoolHistoryItemRequest junior = new SaveSchoolHistoryItemRequest(UUID.randomUUID(), (short) 6,
                (short) 10, "A", (short) 2015, (short) 2019, Stream.ARTS, false);
        assertThat(UserSchoolHistoryService.streamProblem(junior)).contains("only applies");
    }

    @Test
    void streamOkWhenItMatchesTheClasses() {
        assertThat(UserSchoolHistoryService.streamProblem(item(11, 12, 2020, 2022))).isNull();
        assertThat(UserSchoolHistoryService.streamProblem(item(1, 5, 2005, 2009))).isNull();
    }

    @Test
    void singleEntryIsFine() {
        assertThat(UserSchoolHistoryService.overlapProblem(List.of(item(1, 12, 2005, 2017)))).isNull();
    }
}
