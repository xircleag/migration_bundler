/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/6/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler.datasource;

import com.layer.sdk.monkeybutler.MonkeyButler;
import com.layer.sdk.monkeybutler.migrations.Migration;
import com.layer.sdk.monkeybutler.migrations.ResourceMigration;
import com.layer.sdk.monkeybutler.schema.ResourceSchema;
import com.layer.sdk.monkeybutler.schema.Schema;

import java.io.File;
import java.io.IOException;
import java.net.JarURLConnection;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLConnection;
import java.util.Enumeration;
import java.util.LinkedList;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
public class ResourceDataSource implements DataSource {
    private static final String BASE = "resources";
    private static final String SCHEMA = "schema";
    private static final String MIGRATIONS = "migrations";

    private static final String MIGRATIONS_PATH = BASE + "/" + MIGRATIONS;
    private static final String SCHEMA_PATH = BASE + "/" + SCHEMA + "/mb_schema.sql";

    /**
     * Returns whether this DataSource has a Schema entry.
     *
     * @return A boolean representing the presence of a Schema entry in this DataSource.
     */
    @Override
    public boolean hasSchema() {
        return (getSchema() != null);
    }

    /**
     * Returns the Schema entry if it exists, or `null` if it does not.
     *
     * @return The Schema entry if it exists, or `null` if it does not.
     */
    @Override
    public Schema getSchema() {
        try {
            return new ResourceSchema(SCHEMA_PATH);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    /**
     * Returns a list of Migrations bundled in the java resources.
     *
     * We get resource migrations by first getting a known entry in the resource bundle (the
     * schema) and then backing out to find migrations that may also be bundled in the resources.
     * The JAR may either be accessed directly or after expansion on the filesystem, and each case
     * needs its own migration search technique.
     *
     * JAR: iterate through all JAR entries, capturing those whose name starts with
     * `resources/migrations`
     *
     * Filesystem: from the schema entry, back out two levels (to resources), then jump to the
     * migrations directory and iterate over the files in that directory.
     *
     * @return a list of Migrations bundled in the java resources
     */
    @Override
    public List<Migration> getMigrations() {
        List<Migration> migrations = new LinkedList<Migration>();
        try {

            Enumeration<URL> target = MonkeyButler.class.getClassLoader().getResources(SCHEMA_PATH);
            while (target.hasMoreElements()) {
                URL url = target.nextElement();
                URLConnection connection = url.openConnection();

                if (connection instanceof JarURLConnection) {
                    // The schema resource is in a JAR; search within this JAR for migrations.
                    JarURLConnection urlcon = (JarURLConnection) connection;
                    JarFile jar = urlcon.getJarFile();
                    Enumeration<JarEntry> entries = jar.entries();
                    while (entries.hasMoreElements()) {
                        // Path is the item name in the JAR
                        String path = entries.nextElement().getName();
                        if (path.startsWith(MIGRATIONS_PATH)) {
                            migrations.add(new ResourceMigration(path));
                        }
                    }
                } else {
                    // The schema resource is expanded onto the filesystem; jump to the migrations
                    File resourceDir = new File(url.toURI()).getParentFile().getParentFile();
                    File migrationsDir = new File(resourceDir, MIGRATIONS);
                    for (File file : migrationsDir.listFiles()) {
                        // Resource path is still relative to the JAR (not the filesystem)
                        String path = MIGRATIONS_PATH + "/" + file.getName();
                        migrations.add(new ResourceMigration(path));
                    }
                }
            }
            return migrations;
        } catch (IOException e) {
            e.printStackTrace();
        } catch (URISyntaxException e) {
            e.printStackTrace();
        }
        return null;
    }
}
