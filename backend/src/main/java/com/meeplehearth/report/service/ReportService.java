package com.meeplehearth.report.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import com.meeplehearth.report.dto.CreateReportRequest;
import com.meeplehearth.report.entity.Report;
import com.meeplehearth.report.repository.ReportRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Locale;
import java.util.UUID;

/**
 * User reports (FEATURES_COMPLETE 2.4): stored for manual review, at most 5 per reporter per UTC
 * day (Redis counter {@code report:count:{userId}:{yyyy-MM-dd}}). Reporting the same target again
 * succeeds without storing a duplicate.
 */
@Service
public class ReportService {

    static final int DAILY_LIMIT = 5;

    private final ReportRepository reportRepository;
    private final RedisRateLimiter rateLimiter;

    public ReportService(ReportRepository reportRepository, RedisRateLimiter rateLimiter) {
        this.reportRepository = reportRepository;
        this.rateLimiter = rateLimiter;
    }

    static String counterKey(UUID userId, LocalDate day) {
        return "report:count:" + userId + ":" + day;
    }

    @Transactional
    public void report(UUID reporterId, CreateReportRequest req) {
        Report.TargetType type = Report.TargetType.valueOf(req.targetType().trim().toUpperCase(Locale.ROOT));
        if (type == Report.TargetType.USER && req.targetId().equals(reporterId)) {
            throw ApiException.badRequest("INVALID_TARGET", "You cannot report yourself");
        }
        boolean exists = switch (type) {
            case USER -> reportRepository.userExists(req.targetId());
            case POST -> reportRepository.postExists(req.targetId());
            case COMMENT -> reportRepository.commentExists(req.targetId());
        };
        if (!exists) {
            throw ApiException.notFound("REPORT_TARGET_NOT_FOUND", "The reported content was not found");
        }
        if (!rateLimiter.tryAcquire(counterKey(reporterId, LocalDate.now(ZoneOffset.UTC)), DAILY_LIMIT,
                Duration.ofDays(1))) {
            throw ApiException.tooManyRequests("REPORT_LIMIT_EXCEEDED", "You can send up to 5 reports per day");
        }
        reportRepository.insertIfAbsent(reporterId, type.name(), req.targetId(), req.reason().trim());
    }
}
