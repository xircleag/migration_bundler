/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/6/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.monkeybutler.datasource;

import com.layer.monkeybutler.migrations.Migration;
import com.layer.monkeybutler.schema.Schema;

import java.util.List;
public interface DataSource {
    public boolean hasSchema();

    public Schema getSchema();

    public List<Migration> getMigrations();
}
