package com.apsconnect.api.user;

import com.apsconnect.api.common.exception.AppException;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RegistrationValidationTest {

    private final UserRepository userRepository = Mockito.mock(UserRepository.class);
    private final PasswordEncoder passwordEncoder = Mockito.mock(PasswordEncoder.class);
    private final PersonService personService = Mockito.mock(PersonService.class);
    private final UserService service = new UserService(userRepository, passwordEncoder, personService);

    private RegisterUserRequest req(String username, String phone, String email, String fullName, LocalDate dob) {
        return new RegisterUserRequest(username, fullName, phone, email, dob, "Pune", "Student",
                UserStatus.STUDENT, "male");
    }

    private final LocalDate adultDob = LocalDate.now().minusYears(25);

    @Test
    void rejectsInvalidPhone() {
        assertThatThrownBy(() -> service.registerUser(req("alice", "abc", null, "Alice A", adultDob)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("E.164");
    }

    @Test
    void rejectsUnderageUser() {
        assertThatThrownBy(() -> service.registerUser(
                req("kiddo", "+919999000001", null, "Kid K", LocalDate.now().minusYears(10))))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("at least");
    }

    @Test
    void rejectsReservedUsername() {
        assertThatThrownBy(() -> service.registerUser(req("admin", "+919999000001", null, "Ad Min", adultDob)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("reserved");
    }

    @Test
    void rejectsBadEmail() {
        assertThatThrownBy(() -> service.registerUser(req("bob", "+919999000001", "not-an-email", "Bob B", adultDob)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("Email");
    }

    @Test
    void rejectsMissingDob() {
        assertThatThrownBy(() -> service.registerUser(req("carol", "+919999000001", null, "Carol C", null)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("birth");
    }

    @Test
    void acceptsValidAdultAndPersists() {
        Mockito.when(userRepository.existsByUsername(Mockito.anyString())).thenReturn(false);
        Mockito.when(userRepository.existsByPhone(Mockito.anyString())).thenReturn(false);
        Mockito.when(userRepository.save(Mockito.any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserDto dto = service.registerUser(req("dave", "+919999000123", "dave@example.com", "Dave D", adultDob));

        assertThat(dto.username()).isEqualTo("dave");
        Mockito.verify(userRepository).save(Mockito.any(User.class));
    }
}
