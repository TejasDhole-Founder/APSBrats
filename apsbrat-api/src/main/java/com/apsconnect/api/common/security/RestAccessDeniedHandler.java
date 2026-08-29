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
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@RequiredArgsConstructor
public class RestAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper mapper;

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {
        response.setStatus(HttpStatus.FORBIDDEN.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        ApiResponse<Void> body = ApiResponse.error(
                "You do not have access to this resource", ErrorCode.FORBIDDEN.name(), MDC.get(RequestIdFilter.MDC_KEY));
        response.getWriter().write(mapper.writeValueAsString(body));
    }
}
