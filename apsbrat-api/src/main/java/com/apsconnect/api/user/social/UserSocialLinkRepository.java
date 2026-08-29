package com.apsconnect.api.user.social;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserSocialLinkRepository extends JpaRepository<UserSocialLink, UUID> {
    List<UserSocialLink> findAllByUser_IdOrderByCreatedAtDesc(UUID userId);

    Optional<UserSocialLink> findByUser_IdAndPlatform(UUID userId, SocialPlatform platform);

    void deleteAllByUser_Id(UUID userId);
}
