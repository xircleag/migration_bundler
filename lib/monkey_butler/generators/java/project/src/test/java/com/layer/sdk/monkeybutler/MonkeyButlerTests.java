package com.layer.sdk.monkeybutler;

import com.layer.sdk.monkeybutler.migrations.Migration;
import com.layer.sdk.monkeybutler.migrations.ResourceMigration;
import com.layer.sdk.monkeybutler.schema.ResourceSchema;
import com.layer.sdk.monkeybutler.schema.Schema;

import junit.framework.TestCase;

import java.util.List;

import static org.fest.assertions.Assertions.assertThat;

public class MonkeyButlerTests extends TestCase {
    public void testGetInvalidSchema() throws Exception {
        try {
            new ResourceSchema("invalid/path");
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
            new ResourceMigration("invalid/path");
            fail("IllegalArgumentException was not thrown");
        } catch (IllegalArgumentException e) {
        }
    }

    public void testGetValidMigration() throws Exception {
        try {
            new ResourceSchema("resources/migrations/1402070000_Origin.sql");
        } catch (IllegalArgumentException e) {
            fail("IllegalArgumentException was thrown");
        }
    }

    public void testGetMigrations() throws Exception {
        List<Migration> migrations = MonkeyButler.getMigrations();
        assertThat(migrations).hasSize(1);
        assertThat(migrations.get(0).getVersion()).isEqualTo(1402070000L);
        assertThat(migrations.get(0).getDescription()).isEqualTo("Origin");
    }

    public void testGetSchema() throws Exception {
        Schema schema = MonkeyButler.getSchema();
        assertThat(schema).isNotNull();
    }
}
