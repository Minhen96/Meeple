package com.meeplehearth.game.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Dedicated pool for BGG collection imports: imports wait on BGG (202 polling) for up to ~20s,
 * so they must not occupy the shared executor. A full queue rejects the import (reported as
 * BGG_API_UNAVAILABLE) instead of blocking the request thread.
 */
@Configuration
public class BggImportExecutorConfig {

    public static final String BGG_IMPORT_EXECUTOR = "bggImportExecutor";

    @Bean(name = BGG_IMPORT_EXECUTOR)
    public TaskExecutor bggImportExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("bgg-import-");
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}
