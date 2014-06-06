/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/6/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler.schema;

import com.layer.sdk.monkeybutler.MonkeyButler;

import java.io.InputStream;
public class ResourceSchema extends Schema {
    public ResourceSchema(String path) {
        super(path);
    }

    @Override
    public InputStream getStream() {
        return MonkeyButler.class.getClassLoader().getResourceAsStream(getPath());
    }
}
