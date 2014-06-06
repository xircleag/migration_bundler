/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/4/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler;

import android.database.Cursor;
import android.database.SQLException;
import android.database.sqlite.SQLiteDatabase;

import java.io.IOException;
import java.net.JarURLConnection;
import java.net.URL;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class MonkeyButler {
    public static final long NO_VERSIONS = -1;

    public static void bootstrap(SQLiteDatabase db) throws SQLException, IOException {
        SQL.executeResource(db, "schema/schema_create.sql");
    }

    /**
     * Loads the lowest version number from the schema_migrations table, returns NO_VERSIONS if the
     * migrations table is empty, or throws an SQLException if the table isn't present.  The origin
     * version number tells the applyMigrations() method which old migrations it can safely ignore
     * (because they were already applied on the bootstrapped schema deployed on this device).
     *
     * @param db Database from which to load the origin version.
     * @return The lowest version present or NO_VERSIONS of the schema_migrations table is empty.
     * @throws SQLException When no schema_migrations table is present.
     */
    public static long getOriginVersion(SQLiteDatabase db) throws SQLException {
        Cursor cursor = null;
        try {
            cursor = db.rawQuery("SELECT MIN(version) FROM schema_migrations", null);
            cursor.moveToNext();
            if (cursor.isNull(0)) {
                return NO_VERSIONS;
            }
            return cursor.getLong(0);
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }

    /**
     * Loads a set of all versions currently applied on this database.  This set is used by
     * applyMigrations() to determine which available migrations have already been applied.
     *
     * @param db Database from which to load versions.
     * @return An ordered set of all versions applied.
     * @throws SQLException When no schema_migrations table is present.
     */
    public static HashSet<Long> getAllVersions(SQLiteDatabase db) throws SQLException {
        Cursor cursor = null;
        try {
            HashSet<Long> versions = new HashSet<Long>();
            cursor = db.rawQuery("SELECT version FROM schema_migrations ORDER BY version", null);
            while (cursor.moveToNext()) {
                versions.add(cursor.getLong(0));
            }
            return versions;
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }

    /**
     * Generates a list of Migration objects from SQL files located in the assets/migrations
     * directory.  Migration SQL file names must conform to the Migration.MIGRATION_PATTERN
     * pattern and be readily parsed by SQL.executeResource().
     *
     * @return A list of available Migrations as loaded from the assets/migrations directory.
     * @see com.layer.sdk.monkeybutler.Migration#MIGRATION_PATTERN
     * @see com.layer.sdk.monkeybutler.SQL#executeResource(android.database.sqlite.SQLiteDatabase,
     * String)
     */
    public static List<Migration> getAvailableMigrations() {
        List<Migration> migrations = new LinkedList<Migration>();
        Set<String> paths = getResourcePathsByPrefix("migrations/");
        for (String path : paths) {
            migrations.add(new Migration(path));
        }
        Collections.sort(migrations);
        return migrations;
    }

    private static Set<String> getResourcePathsByPrefix(String prefix) {
        Set<String> paths = new HashSet<String>();
        try {
            Enumeration<JarEntry> entries = resourceEntries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                String path = entry.getName();
                if (path.startsWith(prefix)) {
                    paths.add(path);
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return paths;
    }

    private static Enumeration<JarEntry> resourceEntries() throws IOException {
        Enumeration<URL> target = MonkeyButler.class.getClassLoader()
                .getResources("bananabunch/RIPEBANANA.txt");
        if (target.hasMoreElements()) {
            URL url = target.nextElement();
            JarURLConnection urlcon = (JarURLConnection) (url.openConnection());
            JarFile jar = urlcon.getJarFile();
            return jar.entries();
        }
        return null;
    }

    /**
     * Checks the given SQLiteDatabase for schema migrations that need applying.  If the database
     * is fresh, applyMigrations() bootstraps the database with SQL.createSchema().  If the
     * schema_migrations table present but is empty (getOriginVersion() returns NO_VERSIONS),
     * applyMigrations() applies all available migrations from getAvailableMigrations().  If an
     * origin version is present, applyMigrations() applies all available migration versions
     * greater than the origin version.  If no available migrations are greater than the origin
     * version, no migrations are applied.
     *
     * @param db Database on which to operate.
     * @return The number of migrations applied.
     * @see #getOriginVersion(android.database.sqlite.SQLiteDatabase)
     * @see #getAvailableMigrations()
     * @see #getAllVersions(android.database.sqlite.SQLiteDatabase)
     * @see com.layer.sdk.monkeybutler.Migration#migrateDatabase(
     *android.database.sqlite.SQLiteDatabase)
     */
    public static int applyMigrations(SQLiteDatabase db) throws IOException {
        int numApplied = 0;
        try {
            db.beginTransaction();

            // (1) Get the origin version of this database, optionally bootstrapping.
            long originVersion;
            try {
                originVersion = getOriginVersion(db);
            } catch (SQLException e) {
                bootstrap(db);
                originVersion = getOriginVersion(db);
            }

            // (2) Get a list of currently-applied versions.
            HashSet<Long> appliedVersions = getAllVersions(db);

            // (3) Apply unapplied migrations.
            for (Migration migration : getAvailableMigrations()) {
                long version = migration.getVersion();

                if (version <= originVersion) {
                    // Our origin already had this migration applied, continue.
                    continue;
                }

                if (appliedVersions.contains(version)) {
                    // We've already applied this migration, continue.
                    continue;
                }

                // Apply this new migration.
                if (migration.migrateDatabase(db)) {
                    numApplied++;
                } else {
                    throw new IllegalStateException("Could not apply migration.");
                }
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return numApplied;
    }
}
