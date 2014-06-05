/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/4/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler;

import android.content.ContentValues;
import android.content.Context;
import android.database.SQLException;
import android.database.sqlite.SQLiteDatabase;

import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
public class Migration implements Comparable<Migration> {
    private String mPath;
    private Long mVersion;
    private String mDescription;

    private static final Pattern MIGRATION_PATTERN = Pattern.compile("([0-9]+)[_](.*)[.]sql");

    public Migration(String path) {
        String[] parts = path.split("[/]");
        String fileName = parts[parts.length - 1].trim();
        Matcher matcher = MIGRATION_PATTERN.matcher(fileName);
        if (!matcher.matches()) {
            throw new IllegalArgumentException("Invalid file name: " + fileName);
        }
        mPath = path;
        mVersion = Long.parseLong(matcher.group(1));
        mDescription = matcher.group(2);
    }

    public Long getVersion() {
        return mVersion;
    }

    public String getDescription() {
        return mDescription;
    }

    public boolean migrateDatabase(Context context, SQLiteDatabase db) {
        try {
            SQL.executeAsset(context, db, mPath);
            ContentValues values = new ContentValues();
            values.put("version", getVersion());
            db.insert("schema_migrations", null, values);
            return true;
        } catch (SQLException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return false;
    }

    @Override
    public int compareTo(Migration migration) {
        return getVersion().compareTo(migration.getVersion());
    }
}
