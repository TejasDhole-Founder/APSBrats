package com.apsconnect.api.user;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Account creation happens in {@code AuthService} at email-verify / Google
 * sign-in time — a bare account with just an email. Everything here is about
 * an already-authenticated user filling in or changing their own profile.
 */
@Service
@RequiredArgsConstructor
public class UserService {

    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final Pattern USERNAME = Pattern.compile("^[a-zA-Z][a-zA-Z0-9_]{2,19}$");
    private static final int MIN_AGE = 13;
    private static final int MAX_AGE = 120;
    private static final Set<String> RESERVED_USERNAMES = Set.of(
            "admin", "administrator", "root", "support", "help", "apsbrats", "aps",
            "moderator", "mod", "system", "official", "staff", "security");
    private static final Set<String> BLOCKED_USERNAME_TERMS = Set.of(
            "fuck", "shit", "bitch", "cunt", "nigger", "rape");

    private final UserRepository userRepository;
    private final PersonService personService;

    public List<PersonDto> getUsers(int page, int size) {
        return personService.toPeople(
                userRepository.findAllByDeletedAtNull(PageRequest.of(page, size)).getContent());
    }

    @Transactional(readOnly = true)
    public UserDto getMe(UUID userId) {
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        return UserDto.from(user);
    }

    /** The onboarding profile step and the "edit profile" page both land here. */
    @Transactional
    public UserDto updateMe(UUID userId, UpdateProfileRequest request) {
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        String username = request.username().trim();
        String email = blankToNull(request.email());
        if (email != null) {
            email = email.toLowerCase();
        }
        validateProfileFields(request.fullName(), username, email, request.dob());

        if (!username.equals(user.getUsername()) && userRepository.existsByUsername(username)) {
            throw new AppException("Username already exists", HttpStatus.CONFLICT);
        }
        if (email != null && !email.equals(user.getEmail()) && userRepository.existsByEmail(email)) {
            throw new AppException("Email already exists", HttpStatus.CONFLICT);
        }

        user.setUsername(username);
        user.setFullName(request.fullName().trim());
        // Email is the login identity; only overwrite it when one was actually sent
        // (the onboarding profile step doesn't re-send it — it was fixed at login).
        if (email != null) {
            user.setEmail(email);
        }
        user.setDob(request.dob());
        user.setCity(blankToNull(request.city()));
        user.setProfession(blankToNull(request.profession()));
        user.setGender(blankToNull(request.gender()));
        user.setBio(blankToNull(request.bio()));
        if (request.currentStatus() != null) {
            user.setCurrentStatus(request.currentStatus());
        }
        return UserDto.from(user);
    }

    @Transactional(readOnly = true)
    public AvailabilityDto usernameAvailability(String username) {
        String normalized = username == null ? "" : username.trim();
        String problem = usernameProblem(normalized);
        if (problem != null) {
            return AvailabilityDto.no(problem);
        }
        if (userRepository.existsByUsername(normalized)) {
            return AvailabilityDto.no("This username already exists. Please select something else.");
        }
        return AvailabilityDto.ok();
    }

    /** Rules shared by the onboarding profile step and later profile edits. */
    private void validateProfileFields(String fullName, String username, String email, LocalDate dob) {
        if (fullName == null || fullName.trim().length() < 2) {
            throw badRequest("Full name is required");
        }
        if (!username.isBlank()) {
            String problem = usernameProblem(username);
            if (problem != null) {
                throw badRequest(problem);
            }
        }
        if (email != null && !email.isBlank() && !EMAIL.matcher(email).matches()) {
            throw badRequest("Email is not valid");
        }
        if (dob == null) {
            throw badRequest("Date of birth is required");
        }
        if (dob.isAfter(LocalDate.now())) {
            throw badRequest("Date of birth cannot be in the future");
        }
        int age = Period.between(dob, LocalDate.now()).getYears();
        if (age < MIN_AGE) {
            throw badRequest("You must be at least " + MIN_AGE + " years old to register");
        }
        if (age > MAX_AGE) {
            throw badRequest("Date of birth is not valid");
        }
    }

    /** Returns why the username is not acceptable, or null when it passes the format/reserved rules. */
    private String usernameProblem(String username) {
        if (!USERNAME.matcher(username).matches()) {
            return "Username must be 3-20 chars, start with a letter, letters/digits/underscore only";
        }
        String lower = username.toLowerCase();
        if (RESERVED_USERNAMES.contains(lower)) {
            return "This username is reserved";
        }
        if (BLOCKED_USERNAME_TERMS.stream().anyMatch(lower::contains)) {
            return "This username is not allowed";
        }
        return null;
    }

    private AppException badRequest(String message) {
        return new AppException(message, HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR);
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
