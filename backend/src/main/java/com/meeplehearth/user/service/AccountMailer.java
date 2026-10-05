package com.meeplehearth.user.service;

import com.meeplehearth.config.AppProperties;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.util.HtmlUtils;

import java.time.Duration;
import java.util.UUID;

/**
 * Account lifecycle emails (deletion scheduled, email change, data export). Each mail is sent
 * only after the surrounding transaction commits, so a rolled-back change never emails anyone,
 * and a mail failure never fails the request. Addresses and links are never logged.
 *
 * <p>Copy is English or Simplified Chinese, following {@code users.preferred_language}.
 */
@Component
public class AccountMailer {

    private static final Logger log = LoggerFactory.getLogger(AccountMailer.class);
    private static final String DEFAULT_FRONTEND_URL = "http://localhost:5173";

    private final JavaMailSender mailSender;
    private final AppProperties appProperties;

    public AccountMailer(JavaMailSender mailSender, AppProperties appProperties) {
        this.mailSender = mailSender;
        this.appProperties = appProperties;
    }

    /** Base URL of the web app (first allowed CORS origin), used for links in emails. */
    public String frontendUrl() {
        return appProperties.getCors().getAllowedOrigins().isEmpty()
                ? DEFAULT_FRONTEND_URL
                : appProperties.getCors().getAllowedOrigins().get(0);
    }

    public void sendDeletionScheduled(UUID userId, String to, String language) {
        boolean zh = isChinese(language);
        String reactivateUrl = frontendUrl() + "/auth/login";
        sendAfterCommit(userId, "deletion-scheduled", to,
                zh ? "你的 Meeple 账号将被删除" : "Your Meeple account is scheduled for deletion",
                zh ? "你的账号已计划在 30 天后删除。" : "Your account has been scheduled for deletion in 30 days.",
                zh ? "在此期间登录即可恢复你的账号。30 天后，你的个人资料、帖子和图片将被永久删除。"
                        : "Changed your mind? Log in within 30 days to reactivate it. After that, your profile, "
                        + "posts and images are permanently deleted.",
                zh ? "恢复账号" : "Reactivate account",
                reactivateUrl,
                zh ? "如果这不是你本人的操作，请立即登录并修改密码。"
                        : "If you did not request this, log in now and change your password.");
    }

    public void sendEmailChangeVerification(UUID userId, String newEmail, String rawToken, String language,
                                            Duration expiry) {
        boolean zh = isChinese(language);
        String url = frontendUrl() + "/auth/confirm-email-change?token=" + rawToken;
        sendAfterCommit(userId, "email-change-verify", newEmail,
                zh ? "确认你的新 Meeple 邮箱" : "Confirm your new Meeple email",
                zh ? "确认你的新邮箱地址" : "Confirm your new email address",
                zh ? "点击下方按钮，将此邮箱设为你的 Meeple 登录邮箱。"
                        : "Click below to make this address the email for your Meeple account.",
                zh ? "确认邮箱" : "Confirm email",
                url,
                zh ? "链接将在 " + expiry.toHours() + " 小时后失效。如果你没有申请更改，请忽略此邮件。"
                        : "This link expires in " + expiry.toHours() + " hours. If you didn't request this, "
                        + "you can ignore this email.");
    }

    public void sendEmailChangeNotice(UUID userId, String oldEmail, String language) {
        boolean zh = isChinese(language);
        sendAfterCommit(userId, "email-change-notice", oldEmail,
                zh ? "你的 Meeple 邮箱即将更改" : "Your Meeple email is being changed",
                zh ? "有人请求更改你的账号邮箱" : "A change of your account email was requested",
                zh ? "新邮箱确认后，你将需要使用新邮箱登录。"
                        : "Once the new address is confirmed, you will sign in with it instead of this one.",
                zh ? "查看账号" : "Review account",
                frontendUrl() + "/settings",
                zh ? "如果这不是你本人的操作，请立即修改密码。"
                        : "If this wasn't you, change your password now.");
    }

    public void sendExportReady(UUID userId, String to, String language, String downloadUrl, Duration validFor) {
        boolean zh = isChinese(language);
        sendAfterCommit(userId, "export-ready", to,
                zh ? "你的 Meeple 数据导出已就绪" : "Your Meeple data export is ready",
                zh ? "你的数据导出已就绪" : "Your data export is ready",
                zh ? "下载包含你的个人资料、收藏、帖子、活动和通知的 JSON 压缩包。"
                        : "Download a zip of your profile, collection, posts, events and notifications as JSON.",
                zh ? "下载导出" : "Download export",
                downloadUrl,
                zh ? "下载链接将在 " + validFor.toDays() + " 天后失效。"
                        : "The download link expires in " + validFor.toDays() + " days.");
    }

    static boolean isChinese(String language) {
        return language != null && language.toLowerCase().startsWith("zh");
    }

    private void sendAfterCommit(UUID userId, String kind, String to, String subject, String heading,
                                 String body, String buttonLabel, String url, String footer) {
        if (to == null || to.isBlank()) {
            return;
        }
        Runnable send = () -> send(userId, kind, to, subject, buildHtml(heading, body, buttonLabel, url, footer));
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    send.run();
                }
            });
        } else {
            send.run();
        }
    }

    private void send(UUID userId, String kind, String to, String subject, String html) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(appProperties.getEmail().getFrom());
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(html, true);
            mailSender.send(message);
        } catch (Exception e) {
            // Never log the address or the link (it may carry a token)
            log.warn("Failed to send {} email for user {}: {}", kind, userId, e.getClass().getSimpleName());
        }
    }

    static String buildHtml(String heading, String body, String buttonLabel, String url, String footer) {
        return """
                <!DOCTYPE html>
                <html>
                  <body style="font-family: sans-serif; background: #f8f9fa; color: #191c1d; padding: 40px;">
                    <h2 style="color: #895100;">%s</h2>
                    <p>%s</p>
                    <a href="%s"
                       style="display:inline-block; background:#895100; color:#ffffff; padding:12px 24px;
                              border-radius:999px; text-decoration:none; font-weight:bold; margin-top:16px;">
                      %s
                    </a>
                    <p style="margin-top:24px; color:#544434; font-size:14px;">%s</p>
                  </body>
                </html>
                """.formatted(HtmlUtils.htmlEscape(heading), HtmlUtils.htmlEscape(body),
                HtmlUtils.htmlEscape(url), HtmlUtils.htmlEscape(buttonLabel), HtmlUtils.htmlEscape(footer));
    }
}
