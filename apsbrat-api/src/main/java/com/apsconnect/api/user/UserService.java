package com.apsconnect.api.user;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class UserService {

    // E.164: optional leading +, first digit 1-9, total 8-15 digits.
    private static final Pattern PHONE = Pattern.compile("^\\+?[1-9]\\d{7,14}$");
    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final Pattern USERNAME = Pattern.compile("^[a-zA-Z][a-zA-Z0-9_]{2,19}$");
    private static final String PHONE_MESSAGE = "Phone must be a valid number in international (E.164) format";
    private static final int MIN_AGE = 13;
    private static final int MAX_AGE = 120;
    private static final Set<String> RESERVED_USERNAMES = Set.of(
            "admin", "administrator", "root", "support", "help", "apsbrats", "aps",
            "moderator", "mod", "system", "official", "staff", "security");
    private static final Set<String> BLOCKED_USERNAME_TERMS = Set.of(
            "fuck", "shit", "bitch", "cunt", "nigger", "rape");

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final PersonService personService;

    public List<PersonDto> getUsers(int page, int size) {
        return personService.toPeople(
                userRepository.findAllByDeletedAtNull(PageRequest.of(page, size)).getContent());
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

    @Transactional(readOnly = true)
    public AvailabilityDto phoneAvailability(String phone) {
        String normalized = phone == null ? "" : phone.trim();
        if (!PHONE.matcher(normalized).matches()) {
            return AvailabilityDto.no(PHONE_MESSAGE);
        }
        if (userRepository.existsByPhone(normalized)) {
            return AvailabilityDto.no("This phone number is already registered. Please log in instead.");
        }
        return AvailabilityDto.ok();
    }

    @Transactional
    public UserDto registerUser(RegisterUserRequest request) {
        String username = request.username() == null ? "" : request.username().trim();
        String phone = request.phone() == null ? "" : request.phone().trim();
        String email = request.email() == null ? null : request.email().trim().toLowerCase();

        validateRegistration(username, phone, email, request.fullName(), request.dob());

        if (!username.isBlank() && userRepository.existsByUsername(username)) {
            throw new AppException("Username already exists", HttpStatus.CONFLICT);
        }
        if (!phone.isBlank() && userRepository.existsByPhone(phone)) {
            throw new AppException("Phone already exists", HttpStatus.CONFLICT);
        }
        if (email != null && !email.isBlank() && userRepository.existsByEmail(email)) {
            throw new AppException("Email already exists", HttpStatus.CONFLICT);
        }

        User user = new User();
        user.setUsername(username.isBlank() ? null : username);
        user.setFullName(request.fullName() == null ? "" : request.fullName().trim());
        user.setPhone(phone.isBlank() ? null : phone);
        user.setEmail(email == null || email.isBlank() ? null : email);
        user.setDob(request.dob());
        user.setCity(request.city());
        user.setProfession(request.profession());
        user.setGender(request.gender());
        user.setCurrentStatus(request.currentStatus() == null ? UserStatus.STUDENT : request.currentStatus());
        user.setIsVerified(Boolean.FALSE);

        return UserDto.from(userRepository.save(user));
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        if (!request.newPassword().equals(request.confirmPassword())) {
            throw new AppException("newPassword and confirmPassword must match", HttpStatus.BAD_REQUEST);
        }

        validatePasswordStrength(request.newPassword());

        if (user.getPasswordHash() != null && !user.getPasswordHash().isBlank()) {
            if (request.currentPassword() == null || request.currentPassword().isBlank()) {
                throw new AppException("currentPassword is required", HttpStatus.BAD_REQUEST);
            }
            if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
                throw new AppException("currentPassword is incorrect", HttpStatus.BAD_REQUEST);
            }
        }

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);
    }

    private void validateRegistration(String username, String phone, String email, String fullName, LocalDate dob) {
        if (fullName == null || fullName.trim().length() < 2) {
            throw badRequest("Full name is required");
        }
        if (phone.isBlank() || !PHONE.matcher(phone).matches()) {
            throw badRequest(PHONE_MESSAGE);
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

    private void validatePasswordStrength(String password) {
        boolean hasUpper = false;
        boolean hasLower = false;
        boolean hasDigit = false;
        boolean hasSpecial = false;
        for (char ch : password.toCharArray()) {
            if (Character.isUpperCase(ch)) {
                hasUpper = true;
            } else if (Character.isLowerCase(ch)) {
                hasLower = true;
            } else if (Character.isDigit(ch)) {
                hasDigit = true;
            } else if (!Character.isLetterOrDigit(ch)) {
                hasSpecial = true;
            }
        }

        if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
            throw new AppException(
                    "Password must contain uppercase, lowercase, digit, and special character",
                    HttpStatus.BAD_REQUEST
            );
        }
    }
}
