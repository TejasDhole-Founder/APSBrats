package com.apsconnect.api.common.security;

import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.response.ApiResponse;
import com.apsconnect.api.common.web.RequestIdFilter;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class RestAuthEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper mapper;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        ApiResponse<Void> body = ApiResponse.error(
                "Authentication required", ErrorCode.UNAUTHORIZED.name(), MDC.get(RequestIdFilter.MDC_KEY));
        response.getWriter().write(mapper.writeValueAsString(body));
    }
}
