package com.apsconnect.api.circle;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.connection.ConnectionStatus;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import com.apsconnect.api.user.history.UserSchoolHistory;
import com.apsconnect.api.user.history.UserSchoolHistoryRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import java.util.stream.Collectors;

/**
 * "Show me mine": friends, classmates and schoolmates derived from the caller's
 * own connections and school entries. Nothing here runs the people search.
 */
@Service
@RequiredArgsConstructor
public class CircleService {

    public static final int PAGE_SIZE = 30;
    public static final int MAX_PAGE_SIZE = 50;

    private final UserRepository userRepository;
    private final UserSchoolHistoryRepository historyRepository;
    private final ConnectionRepository connectionRepository;
    private final PersonService personService;
    private final CircleCache cache;
    private final ObjectMapper objectMapper;

    // ── Summary ───────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public CircleSummaryDto summary(UUID me) {
        Optional<String> cached = cache.summary(me);
        if (cached.isPresent()) {
            try {
                return objectMapper.readValue(cached.get(), CircleSummaryDto.class);
            } catch (JsonProcessingException ignored) {
                // fall through and recompute
            }
        }
        List<UserSchoolHistory> mine = historyRepository.findAllByUser_Id(me);
        boolean hasSection = mine.stream().anyMatch(h -> h.getSection() != null && !h.getSection().isBlank());
        CircleSummaryDto dto = new CircleSummaryDto(
                connectionRepository.countAcceptedForUser(me),
                connectionRepository.countIncomingWithStatus(me, ConnectionStatus.PENDING),
                connectionRepository.countOutgoingWithStatus(me, ConnectionStatus.PENDING),
                hasSection ? historyRepository.countClassmates(me) : 0,
                mine.isEmpty() ? 0 : historyRepository.countSchoolmates(me),
                hasSection);
        try {
            cache.putSummary(me, objectMapper.writeValueAsString(dto));
        } catch (JsonProcessingException ignored) {
            // cache is an optimisation only
        }
        return dto;
    }

    // ── Classmates ────────────────────────────────────────────────────────────

    /**
     * People who were in the same section of the same school while I was there.
     * {@code entryId} narrows to one of my school entries; null means all of them.
     */
    @Transactional(readOnly = true)
    public List<PersonDto> classmates(UUID me, UUID entryId, int page, int size) {
        requireMyEntry(me, entryId);
        return rankedPage(me, "classmates:" + (entryId == null ? "all" : entryId), () -> entryId == null
                ? historyRepository.findClassmateIds(me)
                : historyRepository.findClassmateIdsForEntry(me, entryId), page, size, false);
    }

    // ── Schoolmates, ranked by mutual friends ─────────────────────────────────

    /**
     * Everyone who attended any of my schools (or one entry's school), ranked by
     * how many friends we share, then same passing year, then name. The ranked id
     * list is cached for a few minutes; paging is a slice of it.
     */
    @Transactional(readOnly = true)
    public List<PersonDto> schoolmates(UUID me, UUID entryId, boolean batchOnly, int page, int size) {
        requireMyEntry(me, entryId);
        String scope = "schoolmates:" + (entryId == null ? "all" : entryId) + (batchOnly ? ":batch" : "");
        return rankedPage(me, scope, () -> entryId == null
                ? historyRepository.findSchoolmateIds(me, batchOnly)
                : historyRepository.findSchoolmateIdsForEntry(me, entryId, batchOnly), page, size, true);
    }

    // ── Shared ranking / paging ───────────────────────────────────────────────

    // ponytail: ranks at most this many candidates (also keeps IN (...) under Postgres' 32k
    // bind-parameter limit); move ranking into SQL if one school's alumni ever exceed it.
    static final int MAX_CANDIDATES = 5000;

    /** Candidates are only queried on a cache miss: a cached page costs one user lookup. */
    private List<PersonDto> rankedPage(UUID me, String scope, Supplier<List<UUID>> candidates,
                                       int page, int size, boolean byMutual) {
        int pageSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int from = Math.max(page, 0) * pageSize;

        List<UUID> ranked = cache.rankedIds(me, scope).orElseGet(() -> {
            List<UUID> ids = candidates.get();
            List<UUID> computed = rank(me, ids.size() > MAX_CANDIDATES ? ids.subList(0, MAX_CANDIDATES) : ids,
                    byMutual);
            cache.putRankedIds(me, scope, computed);
            return computed;
        });
        if (from >= ranked.size()) {
            return List.of();
        }
        List<UUID> slice = ranked.subList(from, Math.min(from + pageSize, ranked.size()));

        Map<UUID, User> byId = userRepository.findAllById(slice).stream()
                .filter(u -> u.getDeletedAt() == null)
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<User> ordered = slice.stream().map(byId::get).filter(u -> u != null).toList();
        return personService.toPeople(ordered, me);
    }

    /** Sort candidates: mutual friends desc (optional), same batch first, then name. */
    List<UUID> rank(UUID me, List<UUID> candidateIds, boolean byMutual) {
        if (candidateIds.isEmpty()) {
            return List.of();
        }
        Map<UUID, Integer> mutual = byMutual ? personService.mutualCounts(me, candidateIds) : Map.of();
        Map<UUID, Boolean> sameBatch = sameBatchAsMe(me, candidateIds);
        Map<UUID, String> names = new HashMap<>();
        for (Object[] row : userRepository.findLiveNames(candidateIds)) {
            names.put((UUID) row[0], row[1] == null ? "" : ((String) row[1]).toLowerCase());
        }
        return rankIds(candidateIds.stream().filter(names::containsKey).toList(), mutual, sameBatch, names);
    }

    /** Pure ordering, kept separate so it can be unit-tested. */
    static List<UUID> rankIds(List<UUID> ids, Map<UUID, Integer> mutual,
                              Map<UUID, Boolean> sameBatch, Map<UUID, String> names) {
        Comparator<UUID> order = Comparator
                .comparingInt((UUID id) -> mutual.getOrDefault(id, 0)).reversed()
                .thenComparing(id -> sameBatch.getOrDefault(id, false) ? 0 : 1)
                .thenComparing(id -> names.getOrDefault(id, ""));
        return ids.stream().distinct().sorted(order).toList();
    }

    private Map<UUID, Boolean> sameBatchAsMe(UUID me, List<UUID> ids) {
        Map<UUID, Boolean> result = new HashMap<>();
        for (UUID id : historyRepository.findSameBatchIds(me, ids)) {
            result.put(id, true);
        }
        return result;
    }

    private void requireMyEntry(UUID me, UUID entryId) {
        if (entryId == null) {
            return;
        }
        boolean mine = historyRepository.findById(entryId)
                .map(h -> h.getUser().getId().equals(me))
                .orElse(false);
        if (!mine) {
            throw new AppException("School entry not found", HttpStatus.NOT_FOUND);
        }
    }
}
