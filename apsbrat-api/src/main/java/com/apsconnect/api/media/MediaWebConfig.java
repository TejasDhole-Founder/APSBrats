package com.apsconnect.api.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Paths;

/** Serves local-disk uploads back over HTTP. Only meaningful alongside {@link LocalStorageService}. */
@Configuration
@ConditionalOnProperty(name = "app.storage.type", havingValue = "local", matchIfMissing = true)
public class MediaWebConfig implements WebMvcConfigurer {

    private final String dir;

    public MediaWebConfig(@Value("${app.media.dir:./media}") String dir) {
        this.dir = dir;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String location = Paths.get(dir).toAbsolutePath().normalize().toUri().toString();
        // Spring only looks inside a folder whose address ends in "/". toUri() adds
        // it only when the folder already exists, which it doesn't on a fresh server.
        if (!location.endsWith("/")) {
            location += "/";
        }
        registry.addResourceHandler("/media/**")
                .addResourceLocations(location)
                .setCachePeriod(3600);
    }
}
