package com.meeplehearth.post.service;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Extracts {@code @username} mentions from comment text (FEATURES_COMPLETE 5.7). Usernames are
 * 3–30 of {@code [A-Za-z0-9_]} and stored lowercase, so results are lower-cased and de-duplicated
 * in order of appearance. An {@code @} preceded by a username character (an e-mail address such
 * as {@code a@b.com}) is not a mention.
 */
public final class MentionParser {

    /** At most this many users are notified per comment (spam guard). */
    public static final int MAX_MENTIONS = 10;

    private static final Pattern MENTION = Pattern.compile("(?<![A-Za-z0-9_])@([A-Za-z0-9_]{3,30})(?![A-Za-z0-9_])");

    private MentionParser() {
    }

    public static Set<String> usernames(String text) {
        Set<String> names = new LinkedHashSet<>();
        if (text == null) {
            return names;
        }
        Matcher matcher = MENTION.matcher(text);
        while (matcher.find() && names.size() < MAX_MENTIONS) {
            names.add(matcher.group(1).toLowerCase(Locale.ROOT));
        }
        return names;
    }
}
