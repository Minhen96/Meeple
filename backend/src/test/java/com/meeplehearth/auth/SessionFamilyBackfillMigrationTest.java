package com.meeplehearth.auth;

import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.transaction.support.TransactionTemplate;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Runs the V62 family_id backfill statements, read from the migration file itself, on synthetic
 * rotation chains. They run against a temporary {@code refresh_tokens} table (temp tables shadow
 * the real one for unqualified names) in a transaction that is rolled back, so real rows are
 * never touched.
 */
class SessionFamilyBackfillMigrationTest extends ApiIntegrationTestBase {

    private static final String MIGRATION = "db/migration/V62__session_families.sql";

    @Autowired private TransactionTemplate transactionTemplate;

    /** The backfill statements of V62: the recursive chain UPDATE and the fallback UPDATE. */
    static List<String> backfillStatements() throws Exception {
        String sql = new ClassPathResource(MIGRATION).getContentAsString(StandardCharsets.UTF_8);
        String withoutComments = sql.lines()
                .filter(line -> !line.trim().startsWith("--"))
                .collect(Collectors.joining("\n"));
        List<String> statements = new ArrayList<>();
        for (String statement : withoutComments.split(";")) {
            String s = statement.trim();
            String upper = s.toUpperCase(Locale.ROOT);
            if ((upper.startsWith("WITH RECURSIVE") || upper.startsWith("UPDATE REFRESH_TOKENS"))
                    && upper.contains("FAMILY_ID")) {
                statements.add(s);
            }
        }
        return statements;
    }

    private void token(UUID id, UUID user, UUID replacedBy) {
        jdbc.update("INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, replaced_by, family_id)"
                        + " VALUES (?, ?, ?, now() + interval '7 days', ?, NULL)",
                id, user, "hash-" + id, replacedBy);
    }

    @Test
    void rotationChainsShareTheFamilyOfTheirRoot() throws Exception {
        List<String> statements = backfillStatements();
        assertThat(statements).hasSize(2);
        assertThat(statements.get(0)).startsWith("WITH RECURSIVE");

        UUID user = UUID.randomUUID();
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();
        UUID c = UUID.randomUUID();
        UUID d = UUID.randomUUID();
        UUID e = UUID.randomUUID();
        UUID single = UUID.randomUUID();

        Map<UUID, UUID> families = transactionTemplate.execute(status -> {
            status.setRollbackOnly();
            jdbc.execute("CREATE TEMP TABLE refresh_tokens (LIKE public.refresh_tokens INCLUDING DEFAULTS) ON COMMIT DROP");
            jdbc.execute("ALTER TABLE refresh_tokens ALTER COLUMN family_id DROP NOT NULL");
            jdbc.execute("ALTER TABLE refresh_tokens ALTER COLUMN family_id DROP DEFAULT");
            // a -> b -> c (two rotations), d -> e (one rotation; d's predecessor was deleted), single
            token(c, user, null);
            token(b, user, c);
            token(a, user, b);
            token(e, user, null);
            token(d, user, e);
            token(single, user, null);
            statements.forEach(jdbc::execute);
            return jdbc.query("SELECT id, family_id FROM refresh_tokens", rs -> {
                Map<UUID, UUID> out = new java.util.HashMap<>();
                while (rs.next()) {
                    out.put(rs.getObject("id", UUID.class), rs.getObject("family_id", UUID.class));
                }
                return out;
            });
        });

        assertThat(families).hasSize(6).doesNotContainValue(null);
        assertThat(families.get(a)).isEqualTo(a);
        assertThat(families.get(b)).isEqualTo(a);
        assertThat(families.get(c)).isEqualTo(a);
        assertThat(families.get(d)).isEqualTo(d);
        assertThat(families.get(e)).isEqualTo(d);
        assertThat(families.get(single)).isEqualTo(single);
        // Rolled back: the real table never saw these rows
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens WHERE id = ?", Integer.class, a)).isZero();
    }
}
