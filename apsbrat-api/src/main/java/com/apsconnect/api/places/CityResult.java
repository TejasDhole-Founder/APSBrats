package com.apsconnect.api.places;

/** One city suggestion, normalised from the geocoding provider's response. */
public record CityResult(
        String city,
        String state,
        String country,
        Double latitude,
        Double longitude,
        String placeId
) {
}
