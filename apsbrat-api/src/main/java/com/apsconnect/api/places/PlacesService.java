package com.apsconnect.api.places;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.fasterxml.jackson.databind.JsonNode;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * City search and reverse lookup through Geoapify. The API key is read from the
 * GEOAPIFY_API_KEY environment variable and never leaves the server.
 */
@Service
public class PlacesService {

    private static final String BASE_URL = "https://api.geoapify.com";
    private static final int MAX_RESULTS = 8;

    private final RestClient client = RestClient.builder().baseUrl(BASE_URL).build();
    private final String apiKey;

    public PlacesService(@Value("${GEOAPIFY_API_KEY:}") String apiKey) {
        this.apiKey = apiKey;
    }

    /** Suggests cities matching the typed text. */
    public List<CityResult> searchCities(String text) {
        requireKey();
        String query = text == null ? "" : text.trim();
        if (query.length() < 2) {
            return List.of();
        }
        String uri = UriComponentsBuilder.fromPath("/v1/geocode/autocomplete")
                .queryParam("text", query)
                .queryParam("type", "city")
                .queryParam("limit", MAX_RESULTS)
                .queryParam("apiKey", apiKey)
                .build()
                .toUriString();
        JsonNode body = client.get().uri(uri).retrieve().body(JsonNode.class);
        return toCities(body);
    }

    /** Finds the city for a coordinate pair, used for the "use my location" button. */
    public CityResult reverseCity(double latitude, double longitude) {
        requireKey();
        String uri = UriComponentsBuilder.fromPath("/v1/geocode/reverse")
                .queryParam("lat", latitude)
                .queryParam("lon", longitude)
                .queryParam("type", "city")
                .queryParam("apiKey", apiKey)
                .build()
                .toUriString();
        JsonNode body = client.get().uri(uri).retrieve().body(JsonNode.class);
        List<CityResult> cities = toCities(body);
        if (cities.isEmpty()) {
            throw new AppException("No city found for this location", HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND);
        }
        return cities.get(0);
    }

    private void requireKey() {
        if (apiKey == null || apiKey.isBlank()) {
            throw new AppException(
                    "City search is not configured", HttpStatus.SERVICE_UNAVAILABLE, ErrorCode.SERVICE_UNAVAILABLE);
        }
    }

    private static List<CityResult> toCities(JsonNode body) {
        List<CityResult> out = new ArrayList<>();
        if (body == null || !body.path("results").isArray()) {
            return out;
        }
        for (JsonNode r : body.path("results")) {
            String city = text(r, "city");
            if (city == null) {
                city = text(r, "name");
            }
            if (city == null) {
                continue;
            }
            out.add(new CityResult(
                    city,
                    text(r, "state"),
                    text(r, "country"),
                    number(r, "lat"),
                    number(r, "lon"),
                    text(r, "place_id")));
        }
        return out;
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node.get(field);
        return v == null || v.isNull() || v.asText().isBlank() ? null : v.asText();
    }

    private static Double number(JsonNode node, String field) {
        JsonNode v = node.get(field);
        return v == null || !v.isNumber() ? null : v.asDouble();
    }
}
