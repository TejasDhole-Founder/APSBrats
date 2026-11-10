package com.apsconnect.api.search;

import com.apsconnect.api.user.PersonDto;

import java.util.List;

public record SearchResultDto(
        List<PersonDto> people
) {
}
