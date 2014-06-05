/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 5/8/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;
public class SQL {
    public static void createSchema(Context context, SQLiteDatabase db) {
        try {
            executeAsset(context, db, "schema/schema_create.sql");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void dropSchema(Context context, SQLiteDatabase db) {
        try {
            executeAsset(context, db, "schema/schema_drop.sql");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * SQL files must have empty newlines between statements.
     *
     * @param assetPath Path of the res/assets sql file to execute.
     * @return A string array with one statement, empty line, or comment per entry.
     * @throws java.io.IOException
     */
    private static List<String> assetToStatements(Context context, String assetPath)
            throws IOException {
        InputStream in = null;
        BufferedReader reader = null;

        try {
            in = context.getAssets().open(assetPath);
            reader = new BufferedReader(new InputStreamReader(in));

            List<String> statements = new LinkedList<String>();
            StringBuilder builder = new StringBuilder();
            String line;
            while (true) {
                line = reader.readLine();
                // End of file; add current builder and break.
                if (line == null) {
                    if (builder.length() > 0) {
                        statements.add(builder.toString());
                    }
                    break;
                }

                // Empty line; add current builder, start a new builder, and continue.
                if (line.trim().isEmpty()) {
                    if (builder.length() > 0) {
                        statements.add(builder.toString());
                    }
                    builder = new StringBuilder();
                    continue;
                }

                // Line with content; append to current builder.
                builder.append(line);
                builder.append("\n");
            }

            return statements;
        } finally {
            if (reader != null) {
                reader.close();
            }

            if (in != null) {
                in.close();
            }
        }
    }

    final static Set<String> COMMENT_PREFIXES = new HashSet<String>(Arrays.asList(
            "--"
    ));

    final static Set<String> EXEC_PREFIXES = new HashSet<String>(Arrays.asList(
            "ALTER", "CREATE", "DELETE", "DROP", "INSERT", "UPDATE"
    ));

    final static Set<String> QUERY_PREFIXES = new HashSet<String>(Arrays.asList(
            "PRAGMA"
    ));

    private static boolean isPrefixMatch(Set<String> prefixes, String statement) {
        String upper = statement.toUpperCase();
        for (String prefix : prefixes) {
            if (upper.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Executes the contents of a given `raw` SQL resource file.
     *
     * @param db        DB on which to execute.
     * @param assetPath Path of the res/assets sql file to execute.
     * @throws java.io.IOException
     */
    public static void executeAsset(Context context, SQLiteDatabase db, String assetPath)
            throws IOException {
        List<String> statements = assetToStatements(context, assetPath);

        for (String statement : statements) {
            statement = statement.trim();

            if (statement.isEmpty()) {
                // Skip empty statements.
                continue;
            }

            if (isPrefixMatch(COMMENT_PREFIXES, statement)) {
                // Skip comments.
                continue;
            }

            if (isPrefixMatch(EXEC_PREFIXES, statement)) {
                // Execute.
                db.execSQL(statement);
                continue;
            }

            if (isPrefixMatch(QUERY_PREFIXES, statement)) {
                // Query.
                db.rawQuery(statement, null);
                continue;
            }

            throw new IllegalArgumentException("Cannot parse statement: " + statement);
        }
    }
}