/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/6/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler.migrations;

import com.layer.sdk.monkeybutler.MonkeyButler;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

public class ResourceMigration extends Migration {
    public static enum Type {
        JAR,
        FILESYSTEM
    }

    private final Type mType;

    public ResourceMigration(Type type, String path) {
        super(path);
        mType = type;
    }

    @Override
    public InputStream getStream() {
        try {
            switch (mType) {
                case JAR:
                    return MonkeyButler.class.getClassLoader().getResourceAsStream(getPath());
                case FILESYSTEM:
                    return new FileInputStream(getPath());
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }
}
