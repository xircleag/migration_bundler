package com.layer.monkeybutler;

import com.layer.monkeybutler.migrations.Migration;
import com.layer.monkeybutler.migrations.ResourceMigration;
import com.layer.monkeybutler.schema.ResourceSchema;
import com.layer.monkeybutler.schema.Schema;

import junit.framework.TestCase;

import java.io.InputStream;
import java.util.List;
import java.util.Scanner;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.fest.assertions.Assertions.assertThat;

public class MonkeyButlerTests extends TestCase {
    public void testGetInvalidSchema() throws Exception {
        try {
            new ResourceSchema("invalid/schema/mb_schema.sql");
            fail("IllegalArgumentException was not thrown");
        } catch (IllegalArgumentException e) {
        }
    }

    public void testGetValidSchema() throws Exception {
        try {
            new ResourceSchema("resources/schema/mb_schema.sql");
        } catch (IllegalArgumentException e) {
            fail("IllegalArgumentException was thrown");
        }
    }

    public void testGetInvalidMigration() throws Exception {
        try {
            new ResourceMigration("invalid/migrations/1402070000_Origin.sql");
            fail("IllegalArgumentException was not thrown");
        } catch (IllegalArgumentException e) {
        }
    }

    public void testGetMigrations() throws Exception {
        List<Migration> migrations = MonkeyButler.getMigrations();
        assertThat(migrations).isNotEmpty();
        for (Migration migration : migrations) {
            assertThat(migration.getVersion()).isNotNull().isGreaterThan(0);
            assertThat(migration.getDescription()).isNotNull().isNotEmpty();
            InputStream in = null;
            try {
                in = migration.getStream();
                assertThat(in).isNotNull();
            } finally {
                if (in != null) {
                    in.close();
                }
            }
        }
    }

    public void testGetMigrationsContainsSchemaOrigin() throws Exception {
        Long originVersion = getValidMigrationVersionFromSchema();
        assertThat(originVersion).isNotNull();

        List<Migration> migrations = MonkeyButler.getMigrations();
        boolean originFound = false;
        for (Migration migration : migrations) {
            if (migration.getVersion().equals(originVersion)) {
                originFound = true;
                break;
            }
        }
        assertTrue(originFound);
    }

    public void testGetSchema() throws Exception {
        Schema schema = MonkeyButler.getSchema();
        assertThat(schema).isNotNull();
        InputStream in = null;
        try {
            in = schema.getStream();
            assertThat(in).isNotNull();
        } finally {
            if (in != null) {
                in.close();
            }
        }
    }

    /**
     * Finds the first `version` inserted into the schema_migrations in the Schema.
     *
     * @return the first `version` inserted into the schema_migrations in the Schema.
     * @throws Exception
     */
    private static Long getValidMigrationVersionFromSchema() throws Exception {
        String schema = new Scanner(MonkeyButler.getSchema().getStream(), "UTF-8")
                .useDelimiter("\\A").next();
        Pattern pattern = Pattern.compile(
                "INSERT\\s*INTO\\s*schema_migrations\\s*\\(\\s*version\\s*\\)\\s*VALUES\\s*\\(\\s*([0-9]*)\\s*\\)",
                Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(schema);
        if (!matcher.find()) {
            return null;
        }
        return Long.parseLong(matcher.group(1));
    }
}
