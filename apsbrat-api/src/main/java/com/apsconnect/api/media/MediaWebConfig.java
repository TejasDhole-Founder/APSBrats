package com.apsconnect.api.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Paths;

@Configuration
public class MediaWebConfig implements WebMvcConfigurer {

    private final String dir;

    public MediaWebConfig(@Value("${app.media.dir:./media}") String dir) {
        this.dir = dir;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String location = Paths.get(dir).toAbsolutePath().normalize().toUri().toString();
        registry.addResourceHandler("/media/**")
                .addResourceLocations(location)
                .setCachePeriod(3600);
    }
}
