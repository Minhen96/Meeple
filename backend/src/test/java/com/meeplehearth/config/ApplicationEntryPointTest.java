package com.meeplehearth.config;

import com.meeplehearth.MeepleBackendApplication;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.web.config.EnableSpringDataWebSupport;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mockStatic;

class ApplicationEntryPointTest {

    @Test
    void mainBootsTheApplicationClassWithTheGivenArguments() {
        String[] args = {"--server.port=0"};
        try (MockedStatic<SpringApplication> spring = mockStatic(SpringApplication.class)) {
            MeepleBackendApplication.main(args);

            spring.verify(() -> SpringApplication.run(MeepleBackendApplication.class, args));
        }
    }

    @Test
    void schedulingAsyncAndStablePageSerializationAreEnabled() {
        Class<MeepleBackendApplication> app = MeepleBackendApplication.class;

        assertThat(app).hasAnnotations(SpringBootApplication.class, EnableScheduling.class, EnableAsync.class);
        // Pages are serialized through PagedModel DTOs, not the unstable PageImpl JSON
        assertThat(app.getAnnotation(EnableSpringDataWebSupport.class).pageSerializationMode())
                .isEqualTo(EnableSpringDataWebSupport.PageSerializationMode.VIA_DTO);
    }
}
