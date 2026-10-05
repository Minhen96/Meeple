package com.meeplehearth.notification.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.ThreadPoolExecutor;

/**
 * Executor for push delivery ({@code @Async("notificationExecutor")}), kept apart from the AI
 * executor so slow FCM calls never queue behind rulebook ingestion. Bounded: when the queue is
 * full the caller thread sends the push itself instead of dropping it.
 */
@Configuration
public class NotificationAsyncConfig {

    public static final String EXECUTOR = "notificationExecutor";

    @Bean(name = EXECUTOR)
    public TaskExecutor notificationExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(1000);
        executor.setThreadNamePrefix("notif-push-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(10);
        executor.initialize();
        return executor;
    }
}
