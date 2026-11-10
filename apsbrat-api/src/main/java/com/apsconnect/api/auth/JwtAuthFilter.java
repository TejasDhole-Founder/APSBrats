package com.apsconnect.api.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import com.apsconnect.api.user.PresenceService;
import io.jsonwebtoken.ExpiredJwtException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);
    /** Every log line of a signed-in request carries this (see logback-spring.xml). */
    public static final String MDC_USER_ID = "userId";

    private final JwtService jwtService;
    private final PresenceService presenceService;
    private final AuthService authService;

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                var claims = jwtService.parseAccess(token);
                UUID userId = claims.userId();
                if (authService.isRevoked(userId, claims.issuedAt())) {
                    throw new IllegalStateException("revoked");
                }
                if (SecurityContextHolder.getContext().getAuthentication() == null) {
                    String role = claims.role();
                    var authorities = role == null || role.isBlank()
                            ? List.<SimpleGrantedAuthority>of()
                            : List.of(new SimpleGrantedAuthority("ROLE_" + role));
                    var auth = new UsernamePasswordAuthenticationToken(userId, null, authorities);
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                }
            } catch (ExpiredJwtException e) {
                // Routine every 15 minutes; the app refreshes and retries.
                log.debug("Expired access token on {}", request.getRequestURI());
            } catch (Exception e) {
                // Context stays unauthenticated, so protected routes 401. Logged: tampered,
                // malformed or revoked tokens are worth seeing.
                log.warn("Rejected access token on {}: {}", request.getRequestURI(), e.toString());
            }
        }
        if (SecurityContextHolder.getContext().getAuthentication() != null
                && SecurityContextHolder.getContext().getAuthentication().getPrincipal() instanceof UUID userId) {
            MDC.put(MDC_USER_ID, userId.toString());
            try {
                presenceService.touch(userId);
            } catch (RuntimeException e) {
                // Presence is best-effort; never fail the request over it.
                log.warn("Could not record activity for {}: {}", userId, e.getMessage());
            }
        }
        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_USER_ID);
        }
    }
}
