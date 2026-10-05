package com.meeplehearth.user.service;

import com.meeplehearth.config.AppProperties;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AccountMailerFeatureTest {

    private final JavaMailSender sender = mock(JavaMailSender.class);
    private final AppProperties props = new AppProperties();
    private final AccountMailer mailer = new AccountMailer(sender, props);
    private final UUID userId = UUID.randomUUID();

    AccountMailerFeatureTest() {
        when(sender.createMimeMessage()).thenAnswer(inv -> new MimeMessage(Session.getInstance(new Properties())));
        props.getCors().setAllowedOrigins(List.of("https://meeple.example"));
    }

    @AfterEach
    void clearSync() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    private MimeMessage sent() {
        ArgumentCaptor<MimeMessage> message = ArgumentCaptor.forClass(MimeMessage.class);
        verify(sender).send(message.capture());
        return message.getValue();
    }

    @Test
    void sendsLocalisedMailImmediatelyOutsideATransaction() throws Exception {
        mailer.sendEmailChangeVerification(userId, "new@example.com", "abc123", "zh-CN", Duration.ofHours(24));
        MimeMessage message = sent();
        assertThat(message.getSubject()).isEqualTo("确认你的新 Meeple 邮箱");
        assertThat(message.getAllRecipients()[0].toString()).isEqualTo("new@example.com");
    }

    @Test
    void waitsForTheCommitInsideATransaction() {
        TransactionSynchronizationManager.initSynchronization();
        mailer.sendDeletionScheduled(userId, "a@example.com", "en");
        verify(sender, never()).send(any(MimeMessage.class));

        for (TransactionSynchronization sync : TransactionSynchronizationManager.getSynchronizations()) {
            sync.afterCommit();
        }
        verify(sender, times(1)).send(any(MimeMessage.class));
    }

    @Test
    void failuresAndMissingAddressesAreSwallowed() {
        doThrow(new MailSendException("smtp down")).when(sender).send(any(MimeMessage.class));
        mailer.sendExportReady(userId, "a@example.com", "en", "https://r2/x?sig=1", Duration.ofDays(7));
        mailer.sendEmailChangeNotice(userId, "old@example.com", null);
        mailer.sendDeletionScheduled(userId, " ", "en");
        verify(sender, times(2)).send(any(MimeMessage.class));
    }

    @Test
    void escapesHtmlAndUsesTheFrontendUrl() {
        String html = AccountMailer.buildHtml("<h>", "a & b", "Go", "https://x/?a=1&b=2", "\"f\"");
        assertThat(html).contains("&lt;h&gt;").contains("a &amp; b").contains("a=1&amp;b=2").contains("&quot;f&quot;");
        assertThat(mailer.frontendUrl()).isEqualTo("https://meeple.example");
        assertThat(new AccountMailer(sender, new AppProperties()).frontendUrl()).isEqualTo("http://localhost:5173");
        assertThat(AccountMailer.isChinese("zh-CN")).isTrue();
        assertThat(AccountMailer.isChinese("en")).isFalse();
        assertThat(AccountMailer.isChinese(null)).isFalse();
    }
}
