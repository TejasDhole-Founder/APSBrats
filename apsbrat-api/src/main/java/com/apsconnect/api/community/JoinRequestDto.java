package com.apsconnect.api.community;

import com.apsconnect.api.user.PersonDto;

import java.time.LocalDateTime;

/** One person waiting to join, as the owner sees it. */
public record JoinRequestDto(PersonDto person, LocalDateTime requestedAt) {
}
