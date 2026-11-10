package com.apsconnect.api.career;

import com.apsconnect.api.common.exception.AppException;
import org.springframework.http.HttpStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CareerService {

    private final CareerEntryRepository entryRepository;
    private final OrganizationRepository organizationRepository;
    private final JobTitleRepository jobTitleRepository;

    @Transactional(readOnly = true)
    public List<OrganizationDto> searchOrganizations(OrgType type, String query) {
        String key = NameKeys.of(query);
        if (key.length() < 2) {
            return List.of();
        }
        return organizationRepository
                .findTop10ByTypeAndNameKeyContainingOrderByStatusDescNameKeyAsc(type, key)
                .stream().map(OrganizationDto::from).toList();
    }

    /** Other people only see entries the owner hasn't hidden. */
    @Transactional(readOnly = true)
    public List<CareerEntryDto> list(UUID viewerId, UUID userId) {
        boolean isOwner = viewerId.equals(userId);
        return entryRepository.findByUserIdOrderByStartDateDesc(userId).stream()
                .filter(e -> isOwner || !e.isHidden())
                .map(CareerEntryDto::from)
                .toList();
    }

    @Transactional
    public CareerEntryDto create(UUID userId, SaveCareerRequest request) {
        CareerEntry entry = new CareerEntry();
        apply(entry, userId, request);
        return CareerEntryDto.from(entryRepository.save(entry));
    }

    @Transactional
    public CareerEntryDto update(UUID userId, UUID entryId, SaveCareerRequest request) {
        CareerEntry entry = ownedEntry(userId, entryId);
        apply(entry, userId, request);
        return CareerEntryDto.from(entryRepository.save(entry));
    }

    @Transactional
    public void delete(UUID userId, UUID entryId) {
        entryRepository.delete(ownedEntry(userId, entryId));
    }

    private CareerEntry ownedEntry(UUID userId, UUID entryId) {
        CareerEntry entry = entryRepository.findById(entryId)
                .orElseThrow(() -> new AppException("Entry not found", HttpStatus.NOT_FOUND));
        if (!entry.getUserId().equals(userId)) {
            throw new AppException("You can only edit your own entries", HttpStatus.FORBIDDEN);
        }
        return entry;
    }

    private void apply(CareerEntry entry, UUID userId, SaveCareerRequest r) {
        if (r.endDate() != null && r.endDate().isBefore(r.startDate())) {
            throw new AppException("End date can't be before the start date", HttpStatus.BAD_REQUEST);
        }
        OrgType type = r.kind() == CareerKind.WORK ? OrgType.COMPANY : OrgType.INSTITUTION;
        String title = r.title().trim();

        entry.setUserId(userId);
        entry.setKind(r.kind());
        entry.setOrganization(resolveOrganization(type, r, userId));
        entry.setTitle(title);
        // Link to the known title list when it matches; a title nobody has listed still saves.
        entry.setJobTitleId(r.kind() == CareerKind.WORK
                ? jobTitleRepository.findByTitleKey(title.toLowerCase(Locale.ROOT)).map(JobTitle::getId).orElse(null)
                : null);
        entry.setFieldOfStudy(blankToNull(r.fieldOfStudy()));
        entry.setLocation(blankToNull(r.location()));
        entry.setDescription(blankToNull(r.description()));
        entry.setStartDate(r.startDate());
        entry.setEndDate(r.endDate());
        entry.setHidden(Boolean.TRUE.equals(r.isHidden()));
    }

    /** Picked from the list -> use it. Typed -> reuse a matching one, or add it as UNVERIFIED. */
    private Organization resolveOrganization(OrgType type, SaveCareerRequest r, UUID userId) {
        if (r.organizationId() != null) {
            Organization org = organizationRepository.findById(r.organizationId())
                    .orElseThrow(() -> new AppException("Organization not found", HttpStatus.NOT_FOUND));
            if (org.getType() != type) {
                throw new AppException("That organization can't be used for this kind of entry", HttpStatus.BAD_REQUEST);
            }
            return org;
        }
        String name = r.organizationName() == null ? "" : r.organizationName().trim();
        String key = NameKeys.of(name);
        if (key.isEmpty()) {
            throw new AppException("Pick or enter a company / college", HttpStatus.BAD_REQUEST);
        }
        // ponytail: two people adding the same new name at the same instant can hit the unique
        // key once; they just retry. Add a catch + re-read if it ever shows up in logs.
        return organizationRepository.findByTypeAndNameKey(type, key).orElseGet(() -> {
            Organization org = new Organization();
            org.setType(type);
            org.setName(name);
            org.setNameKey(key);
            org.setCreatedBy(userId);
            return organizationRepository.save(org);
        });
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}