package com.meeplehearth.post;

import com.meeplehearth.post.service.MentionParser;
import org.junit.jupiter.api.Test;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;

class MentionParserTest {

    @Test
    void extractsLowercasedDistinctUsernamesInOrder() {
        assertThat(MentionParser.usernames("GG @Alice, @bob_99 and @ALICE! (@carol)"))
                .containsExactly("alice", "bob_99", "carol");
    }

    @Test
    void ignoresEmailsTooShortTooLongAndNull() {
        assertThat(MentionParser.usernames("mail me@host.com @ab @" + "x".repeat(31) + " @ok_user")).containsExactly("ok_user");
        assertThat(MentionParser.usernames(null)).isEmpty();
        assertThat(MentionParser.usernames("no mentions")).isEmpty();
    }

    @Test
    void capsTheNumberOfMentions() {
        String text = IntStream.range(0, 15).mapToObj(i -> "@user" + i).collect(Collectors.joining(" "));
        assertThat(MentionParser.usernames(text)).hasSize(MentionParser.MAX_MENTIONS);
    }
}
