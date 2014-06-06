/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/6/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler.datasource;

import com.layer.sdk.monkeybutler.migrations.Migration;
import com.layer.sdk.monkeybutler.schema.Schema;

import java.util.List;
public interface DataSource {
    public boolean hasSchema();

    public Schema getSchema();

    public List<Migration> getMigrations();
}
