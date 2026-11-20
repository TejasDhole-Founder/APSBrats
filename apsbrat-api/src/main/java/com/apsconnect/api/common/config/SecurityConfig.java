package com.apsconnect.api.common.config;

import com.apsconnect.api.auth.JwtAuthFilter;
import com.apsconnect.api.common.security.RestAccessDeniedHandler;
import com.apsconnect.api.common.security.RestAuthEntryPoint;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authorization.AuthorizationDecision;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final RestAuthEntryPoint authEntryPoint;
    private final RestAccessDeniedHandler accessDeniedHandler;

    /** Local testing only: lets a scraper read /actuator/prometheus and /actuator/metrics without a login. Off everywhere else. */
    @Value("${app.actuator.public-metrics:false}")
    private boolean publicMetrics;

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http.csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                // On top of Spring's defaults (nosniff, X-Frame-Options DENY, no-cache).
                // CSP limits framing and plugins only, so Swagger UI's scripts keep working.
                .headers(h -> h
                        .httpStrictTransportSecurity(hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(31536000))
                        .referrerPolicy(r -> r.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER))
                        .contentSecurityPolicy(csp -> csp.policyDirectives(
                                "frame-ancestors 'none'; object-src 'none'; base-uri 'none'"))
                        .permissionsPolicy(p -> p.policy("camera=(), microphone=(), geolocation=()")))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/actuator/health/**", "/actuator/health").permitAll()
                        // Build version and time only: lets on-call tie a failure to a release.
                        .requestMatchers("/actuator/info").permitAll()
                        .requestMatchers("/actuator/prometheus", "/actuator/metrics", "/actuator/metrics/**").access((a, c) ->
                                new AuthorizationDecision(publicMetrics))
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                        .requestMatchers("/ws/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/media/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/app/config").permitAll()
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/schools/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/users/username-available").permitAll()
                        // School history and social links used to be public; both now require
                        // login, and the write endpoints additionally check the path id is the
                        // caller's own (see UserSchoolHistoryController / UserSocialLinkController).
                        // Sends real email through our provider account: admins only, not moderators.
                        .requestMatchers("/api/v1/admin/email/**").hasRole("ADMIN")
                        .requestMatchers("/api/v1/admin/**").hasAnyRole("ADMIN", "MODERATOR")
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(authEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(
            @org.springframework.beans.factory.annotation.Value("${app.cors.allowed-origins:http://localhost:*,http://127.0.0.1:*}")
            List<String> allowedOrigins) {
        CorsConfiguration configuration = new CorsConfiguration();
        // Browsers only: the mobile app doesn't use CORS. qa/prod set CORS_ALLOWED_ORIGINS.
        configuration.setAllowedOriginPatterns(allowedOrigins);
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
