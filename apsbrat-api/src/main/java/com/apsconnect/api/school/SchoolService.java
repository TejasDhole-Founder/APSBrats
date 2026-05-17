package com.apsconnect.api.school;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SchoolService {
    private final SchoolRepository schoolRepository;

    public List<SchoolDto> getSchools(int page, int size) {
        return schoolRepository.findAll(PageRequest.of(page, size))
                .stream()
                .map(SchoolDto::from)
                .toList();
    }
}
