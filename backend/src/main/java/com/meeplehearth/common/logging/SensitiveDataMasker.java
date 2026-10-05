package com.meeplehearth.common.logging;

import com.fasterxml.jackson.core.JsonStreamContext;
import net.logstash.logback.mask.ValueMasker;

import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Last line of defence for the JSON logs (TECH_STACK_ADDITIONS section 22: never log passwords,
 * tokens or email addresses; mask FCM tokens). Plugged into the prod encoder in
 * {@code logback-spring.xml}; applied to every string value written, including the message and
 * stack traces.
 * <ul>
 *   <li>fields whose name looks sensitive (password, token, secret, authorization, cookie,
 *       email) are replaced entirely;</li>
 *   <li>inside any other string: email addresses, JWTs, {@code Bearer} credentials, long hex
 *       tokens (refresh / verification / reset tokens), FCM registration tokens and
 *       {@code token=} style query parameters are masked.</li>
 * </ul>
 * Code must still never log these; this only limits the damage when it happens.
 */
public class SensitiveDataMasker implements ValueMasker {

    public static final String MASK = "****";

    private static final Set<String> SENSITIVE_FIELD_PARTS = Set.of(
            "password", "token", "secret", "authorization", "cookie", "email", "apikey", "api_key");

    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static final Pattern JWT = Pattern.compile("eyJ[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]{5,}");
    private static final Pattern BEARER = Pattern.compile("(?i)(bearer\\s+)[A-Za-z0-9._~+/=-]+");
    /** FCM registration tokens: "<instance id>:APA91b<long base64url>". */
    private static final Pattern FCM_TOKEN = Pattern.compile("[A-Za-z0-9_-]{8,}:APA91[A-Za-z0-9_-]{20,}");
    private static final Pattern HEX_TOKEN = Pattern.compile("\\b[0-9a-fA-F]{40,}\\b");
    private static final Pattern TOKEN_PARAM = Pattern.compile(
            "(?i)((?:token|password|secret|code)=)[^&\\s\"']+");

    @Override
    public Object mask(JsonStreamContext context, Object value) {
        if (!(value instanceof CharSequence text)) {
            return value;
        }
        String field = context == null ? null : context.getCurrentName();
        if (isSensitiveField(field)) {
            return MASK;
        }
        String masked = maskText(text.toString());
        return masked.contentEquals(text) ? value : masked;
    }

    static boolean isSensitiveField(String field) {
        if (field == null) {
            return false;
        }
        String lower = field.toLowerCase(Locale.ROOT);
        return SENSITIVE_FIELD_PARTS.stream().anyMatch(lower::contains);
    }

    /** Masks every sensitive value inside free text. */
    public static String maskText(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        String result = JWT.matcher(text).replaceAll(MASK);
        result = BEARER.matcher(result).replaceAll("$1" + MASK);
        result = FCM_TOKEN.matcher(result).replaceAll(MASK);
        result = TOKEN_PARAM.matcher(result).replaceAll("$1" + MASK);
        result = HEX_TOKEN.matcher(result).replaceAll(MASK);
        result = EMAIL.matcher(result).replaceAll(MASK);
        return result;
    }
}
