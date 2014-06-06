package com.layer.sdk.monkeybutler;

import com.layer.sdk.monkeybutler.migrations.Migration;
import com.layer.sdk.monkeybutler.schema.Schema;

import junit.framework.TestCase;

import java.util.List;

import static org.fest.assertions.Assertions.assertThat;

public class MonkeyButlerTests extends TestCase {
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
