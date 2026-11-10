package com.apsconnect.api.common.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.File;

/**
 * The "dev" profile is the default when SPRING_PROFILES_ACTIVE isn't set, and it
 * accepts the universal OTP and a weak JWT secret. A deployed container (Docker
 * or Kubernetes) that forgot to set a profile must not quietly run like that.
 * Running locally, or setting SPRING_PROFILES_ACTIVE=dev on purpose, is unaffected.
 */
@Component
@Profile("dev")
public class DevProfileGuard {

    @PostConstruct
    void refuseAccidentalDevInContainer() {
        boolean explicit = System.getenv("SPRING_PROFILES_ACTIVE") != null;
        boolean deployed = System.getenv("KUBERNETES_SERVICE_HOST") != null || new File("/.dockerenv").exists();
        if (deployed && !explicit) {
            throw new IllegalStateException(
                    "Running in a container with no SPRING_PROFILES_ACTIVE: set it to qa or prod "
                            + "(or to dev on purpose). Refusing to start with the dev defaults.");
        }
    }
}
