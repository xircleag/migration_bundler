/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/4/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler.migrations;

import java.io.InputStream;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
public abstract class Migration implements Comparable<Migration> {
    public static final Pattern MIGRATION_PATTERN = Pattern.compile("([0-9]+)[_](.*)[.]sql");

    private String mPath;
    private Long mVersion;
    private String mDescription;

    protected Migration(String path) {
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

    protected String getPath() {
        return mPath;
    }

    public Long getVersion() {
        return mVersion;
    }

    public String getDescription() {
        return mDescription;
    }

    protected abstract InputStream getStream();

    @Override
    public int compareTo(Migration migration) {
        return getVersion().compareTo(migration.getVersion());
    }
}
