package com.apsconnect.api.search;

import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.UserStatus;
import com.apsconnect.api.user.history.Stream;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * People search: the text box is for WHO (name / username), the filters are for
 * WHERE (school, batch, class, section, stream, status, city). Everything runs
 * in one SQL statement, filters first, then ranked and paged — see
 * {@link UserRepository#searchPeople}.
 */
@Service
@RequiredArgsConstructor
public class PeopleSearchService {

    public static final int DEFAULT_PAGE_SIZE = 30;
    public static final int MAX_PAGE_SIZE = 50;

    private final UserRepository userRepository;
    private final PersonService personService;

    /** Optional narrowing. Any null field means "don't filter on this". */
    public record Filters(UUID schoolId, Short batch, Short classTo, String section, Stream stream,
                          UserStatus status, String city) {

        boolean usesSchoolHistory() {
            return schoolId != null || batch != null || classTo != null || section != null || stream != null;
        }
    }

    @Transactional(readOnly = true)
    public List<PersonDto> search(UUID viewerId, String query, Filters filters, boolean scopeMine, int page, int size) {
        int pageSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int offset = Math.max(page, 0) * pageSize;

        String normalized = normalize(query);
        List<String> tokens = tokens(normalized);

        List<User> users = userRepository.searchPeople(
                viewerId,
                normalized.isEmpty() ? null : normalized,
                tokens.isEmpty() ? null : "%" + tokens.get(0) + "%",
                tokens.isEmpty() ? null : wordPrefixPattern(tokens),
                scopeMine,
                filters.usesSchoolHistory(),
                filters.schoolId(),
                filters.batch(),
                filters.classTo(),
                filters.section() == null ? null : filters.section().toUpperCase(Locale.ROOT),
                filters.stream() == null ? null : filters.stream().name(),
                filters.status() == null ? null : filters.status().name(),
                filters.city() == null ? null : filters.city().toLowerCase(Locale.ROOT),
                pageSize,
                offset);

        return personService.toPeople(users, viewerId);
    }

    /** Lower-case, collapse whitespace. */
    static String normalize(String query) {
        return query == null ? "" : query.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
    }

    /** "amit  pra" → ["amit", "pra"]; punctuation users type by accident is dropped. */
    static List<String> tokens(String normalized) {
        if (normalized.isEmpty()) {
            return List.of();
        }
        return Arrays.stream(normalized.split("[\\s.,_-]+"))
                .filter(t -> !t.isBlank())
                .limit(5)
                .toList();
    }

    /**
     * Postgres regex that is true when EVERY token starts some word of the
     * haystack ("full name" + " " + username). Word boundaries are spaces and the
     * separators used in usernames. Example: ["amit","pra"] matches "Amit Prasad"
     * and "seed.amit.prasad.7" but not "Sumit Prakash".
     */
    static String wordPrefixPattern(List<String> tokens) {
        StringBuilder sb = new StringBuilder("^");
        for (String token : tokens) {
            sb.append("(?=.*(^|[ ._-])").append(escapeRegex(token)).append(')');
        }
        return sb.toString();
    }

    /** Backslash-escape regex metacharacters (valid for both Postgres ARE and Java). */
    static String escapeRegex(String token) {
        StringBuilder sb = new StringBuilder();
        for (char ch : token.toCharArray()) {
            if ("\\^$.|?*+()[]{}".indexOf(ch) >= 0) {
                sb.append('\\');
            }
            sb.append(ch);
        }
        return sb.toString();
    }
}
