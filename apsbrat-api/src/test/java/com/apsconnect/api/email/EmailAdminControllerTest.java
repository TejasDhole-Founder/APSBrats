package com.apsconnect.api.email;

import com.apsconnect.api.common.exception.GlobalExceptionHandler;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Who may call these endpoints is decided in SecurityConfig (ADMIN only); this checks what they do. */
class EmailAdminControllerTest {

    private final EmailService emailService = Mockito.mock(EmailService.class);
    private final UserRepository userRepository = Mockito.mock(UserRepository.class);
    private final UUID admin = UUID.randomUUID();
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new EmailAdminController(emailService, userRepository))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(admin, null, List.of()));
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void healthReturnsTheCheckWithoutAnySecret() throws Exception {
        when(emailService.health()).thenReturn(new EmailHealth("UP", "brevo", true, true, true, true,
                "no-reply@apsbrats.com", 120L, "The API key works and the sender is active.", Instant.now()));

        mvc.perform(get("/api/v1/admin/email/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.status").value("UP"))
                .andExpect(jsonPath("$.data.apiKeySet").value(true))
                .andExpect(jsonPath("$.data.senderVerified").value(true))
                .andExpect(jsonPath("$.data.apiKey").doesNotExist());
    }

    @Test
    void testEmailGoesToTheGivenAddress() throws Exception {
        when(emailService.sendTest("friend@gmail.com", admin)).thenReturn(
                new EmailService.TestResult(true, "brevo", "f***@gmail.com", "<id>", null));

        mvc.perform(post("/api/v1/admin/email/test").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"to\":\"friend@gmail.com\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sent").value(true))
                .andExpect(jsonPath("$.data.sentTo").value("f***@gmail.com"))
                .andExpect(jsonPath("$.data.messageId").value("<id>"));
    }

    @Test
    void testEmailDefaultsToTheAdminsOwnAccountAddress() throws Exception {
        User user = new User();
        user.setEmail("me@yardi.com");
        when(userRepository.findById(admin)).thenReturn(Optional.of(user));
        when(emailService.sendTest(eq("me@yardi.com"), eq(admin))).thenReturn(
                new EmailService.TestResult(true, "brevo", "m***@yardi.com", "<id>", null));

        mvc.perform(post("/api/v1/admin/email/test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sent").value(true));

        verify(emailService).sendTest("me@yardi.com", admin);
    }

    @Test
    void anInvalidAddressIsRejectedBeforeAnythingIsSent() throws Exception {
        mvc.perform(post("/api/v1/admin/email/test").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"to\":\"not-an-email\"}"))
                .andExpect(status().isBadRequest());

        verify(emailService, never()).sendTest(any(), any());
    }

    @Test
    void noAddressAndNoAccountEmailIs400() throws Exception {
        when(userRepository.findById(admin)).thenReturn(Optional.of(new User()));

        mvc.perform(post("/api/v1/admin/email/test"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));

        verify(emailService, never()).sendTest(any(), any());
    }
}
