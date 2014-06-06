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
import java.io.InputStream;
import java.net.JarURLConnection;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLConnection;
import java.util.Enumeration;
import java.util.LinkedList;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import sun.net.www.protocol.file.FileURLConnection;
public class ResourceDataSource implements DataSource {
    private static final String BASE = "resources";
    private static final String SCHEMA = "schema";
    private static final String MIGRATIONS = "migrations";

    private static final String MIGRATIONS_PATH = BASE + "/" + MIGRATIONS;
    private static final String SCHEMA_PATH = BASE + "/" + SCHEMA + "/mb_schema.sql";

    @Override
    public boolean hasSchema() {
        Schema schema = getSchema();
        InputStream in = null;
        try {
            in = schema.getStream();
            if (in != null) {
                return true;
            }
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        return false;
    }

    @Override
    public Schema getSchema() {
        return new ResourceSchema(SCHEMA_PATH);
    }

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
                        String path = entries.nextElement().getName();
                        if (path.startsWith(MIGRATIONS_PATH)) {
                            migrations.add(new ResourceMigration(ResourceMigration.Type.JAR, path));
                        }
                    }
                } else if (connection instanceof FileURLConnection) {
                    // The schema resource is expanded onto the filesystem; jump to the migrations
                    File resourceDir = new File(url.toURI()).getParentFile().getParentFile();
                    File migrationsDir = new File(resourceDir, MIGRATIONS);
                    for (File file : migrationsDir.listFiles()) {
                        migrations.add(new ResourceMigration(ResourceMigration.Type.FILESYSTEM,
                                file.getAbsolutePath()));
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
