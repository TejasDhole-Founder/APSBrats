package com.apsconnect.api.user;

import com.apsconnect.api.common.exception.AppException;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Account creation now happens in AuthService (a bare row keyed by email) —
 * these fields are all validated when the onboarding profile step calls
 * updateMe, so that's what's under test here.
 */
class RegistrationValidationTest {

    private final UserRepository userRepository = Mockito.mock(UserRepository.class);
    private final PersonService personService = Mockito.mock(PersonService.class);
    private final UserService service = new UserService(userRepository, personService);

    private final UUID userId = UUID.randomUUID();
    private final LocalDate adultDob = LocalDate.now().minusYears(25);

    private UpdateProfileRequest req(String username, String fullName, String email, LocalDate dob) {
        return new UpdateProfileRequest(fullName, username, email, "Pune", "Student", "male", dob, null,
                UserStatus.STUDENT);
    }

    private void givenExistingUser() {
        User user = new User();
        user.setId(userId);
        Mockito.when(userRepository.findById(userId)).thenReturn(Optional.of(user));
    }

    @Test
    void rejectsUnderageUser() {
        givenExistingUser();
        assertThatThrownBy(() -> service.updateMe(userId,
                req("kiddo", "Kid K", null, LocalDate.now().minusYears(10))))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("at least");
    }

    @Test
    void rejectsReservedUsername() {
        givenExistingUser();
        assertThatThrownBy(() -> service.updateMe(userId, req("admin", "Ad Min", null, adultDob)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("reserved");
    }

    @Test
    void rejectsBadEmail() {
        givenExistingUser();
        assertThatThrownBy(() -> service.updateMe(userId, req("bob", "Bob B", "not-an-email", adultDob)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("Email");
    }

    @Test
    void rejectsMissingDob() {
        givenExistingUser();
        assertThatThrownBy(() -> service.updateMe(userId, req("carol", "Carol C", null, null)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("birth");
    }

    @Test
    void acceptsValidAdultAndPersists() {
        givenExistingUser();
        Mockito.when(userRepository.existsByUsername(Mockito.anyString())).thenReturn(false);

        UserDto dto = service.updateMe(userId, req("dave", "Dave D", "dave@example.com", adultDob));

        assertThat(dto.username()).isEqualTo("dave");
    }
}
