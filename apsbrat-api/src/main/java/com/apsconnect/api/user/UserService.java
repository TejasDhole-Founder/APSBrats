package com.apsconnect.api.user;

import com.apsconnect.api.common.exception.AppException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public List<UserDto> getUsers(int page, int size) {
        return userRepository.findAll(PageRequest.of(page, size))
                .stream()
                .map(UserDto::from)
                .toList();
    }

    @Transactional
    public UserDto registerUser(RegisterUserRequest request) {
        String username = request.username() == null ? "" : request.username().trim();
        String phone = request.phone() == null ? "" : request.phone().trim();
        String email = request.email() == null ? null : request.email().trim().toLowerCase();

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

    private void validatePasswordStrength(String password) {
        boolean hasUpper = password.chars().anyMatch(Character::isUpperCase);
        boolean hasLower = password.chars().anyMatch(Character::isLowerCase);
        boolean hasDigit = password.chars().anyMatch(Character::isDigit);
        boolean hasSpecial = password.chars().anyMatch(ch -> !Character.isLetterOrDigit(ch));

        if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
            throw new AppException(
                    "Password must contain uppercase, lowercase, digit, and special character",
                    HttpStatus.BAD_REQUEST
            );
        }
    }
}
