/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 6/4/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler;

import com.layer.sdk.monkeybutler.datasource.DataSource;
import com.layer.sdk.monkeybutler.datasource.ResourceDataSource;
import com.layer.sdk.monkeybutler.migrations.Migration;
import com.layer.sdk.monkeybutler.schema.Schema;

import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

public class MonkeyButler {
    /**
     * List of DataSources from which to get Schemas and Migrations.
     */
    private static final List<DataSource> sDataSources = Arrays.asList(
            (DataSource) new ResourceDataSource()
    );

    /**
     * Returns the first available Schema contained within the DataSource list.
     *
     * @return The first available Schema contained within the DataSource list.
     */
    public static Schema getSchema() {
        for (DataSource dataSource : sDataSources) {
            if (dataSource.hasSchema()) {
                return dataSource.getSchema();
            }
        }
        return null;
    }

    /**
     * Returns a sorted list of all Migrations contained within the DataSource list.
     *
     * @return A sorted list of all Migrations contained within the DataSource list.
     */
    public static List<Migration> getMigrations() {
        List<Migration> migrations = new LinkedList<Migration>();
        for (DataSource dataSource : sDataSources) {
            migrations.addAll(dataSource.getMigrations());
        }
        Collections.sort(migrations);
        return migrations;
    }
}
