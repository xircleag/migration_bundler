/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/6/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.monkeybutler.migrations;

import com.layer.monkeybutler.MonkeyButler;

import java.io.InputStream;

public class ResourceMigration extends Migration {
    public ResourceMigration(String path) {
        super(path);
        if (MonkeyButler.class.getClassLoader().getResource(path) == null) {
            throw new IllegalArgumentException("Resource does not contain '" + path + "'");
        }
    }

    @Override
    public InputStream getStream() {
        return MonkeyButler.class.getClassLoader().getResourceAsStream(getPath());
    }
}
