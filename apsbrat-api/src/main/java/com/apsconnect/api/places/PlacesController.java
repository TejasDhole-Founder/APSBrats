package com.apsconnect.api.places;

import com.apsconnect.api.common.response.ApiResponse;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/places")
public class PlacesController {

    private final PlacesService places;

    public PlacesController(PlacesService places) {
        this.places = places;
    }

    @GetMapping("/cities")
    public ResponseEntity<ApiResponse<List<CityResult>>> searchCities(@RequestParam String q) {
        return ResponseEntity.ok(ApiResponse.success(places.searchCities(q)));
    }

    @GetMapping("/reverse")
    public ResponseEntity<ApiResponse<CityResult>> reverse(
            @RequestParam double lat,
            @RequestParam double lon) {
        return ResponseEntity.ok(ApiResponse.success(places.reverseCity(lat, lon)));
    }
}
