package com.apsconnect.api.user;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.security.SecurityUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.UUID;

/**
 * Social features are for people who finished basic onboarding. An account that
 * only verified its email can reach login, its own profile and the onboarding
 * steps (schools, career, socials, photo), and nothing else.
 */
@Configuration
@RequiredArgsConstructor
public class OnboardingGate implements WebMvcConfigurer {

    private final UserRepository userRepository;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override
            public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
                UUID userId = SecurityUtils.currentUserIdOrNull();
                if (userId == null || "OPTIONS".equals(request.getMethod())) {
                    return true;
                }
                boolean onboarded = userRepository.findById(userId).map(User::isOnboarded).orElse(false);
                if (!onboarded) {
                    throw new AppException("Finish setting up your profile first", HttpStatus.FORBIDDEN,
                            ErrorCode.FORBIDDEN);
                }
                return true;
            }
        }).addPathPatterns(
                "/api/v1/communities/**",
                "/api/v1/posts/**",
                "/api/v1/comments/**",
                "/api/v1/events/**",
                "/api/v1/community-messages/**",
                "/api/v1/conversations/**",
                "/api/v1/connections/**",
                "/api/v1/reports",
                "/api/v1/people/**",
                "/api/v1/search/**",
                "/api/v1/feed/**",
                "/api/v1/users/me/circle/**",
                "/api/v1/profiles/**",
                "/api/v1/users/*/block");
    }
}
