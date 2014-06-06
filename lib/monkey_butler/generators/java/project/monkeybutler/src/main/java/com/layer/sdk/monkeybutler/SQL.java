/**
 * Layer Android SDK
 *
 * Created by Steven Jones on 5/8/14
 * Copyright (c) 2013 Layer. All rights reserved.
 */
package com.layer.sdk.monkeybutler;

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
    /**
     * SQL files must have empty newlines between statements.
     *
     * @param resourcePath Path of the resource sql file to execute.
     * @return A string array with one statement, empty line, or comment per entry.
     * @throws java.io.IOException
     */
    private static List<String> resourceToStatements(String resourcePath) throws IOException {
        InputStream in = null;
        BufferedReader reader = null;

        try {
            in = MonkeyButler.class.getClassLoader().getResourceAsStream(resourcePath);
            reader = new BufferedReader(new InputStreamReader(in));

            List<String> statements = new LinkedList<String>();
            StringBuilder builder = new StringBuilder();
            String line;
            while (true) {
                line = reader.readLine();
                // End of file; add current builder and break.
                if (line == null) {
                    if (builder.length() > 0) {
                        statements.add(builder.toString().trim());
                    }
                    break;
                }

                // Empty line; add current builder, start a new builder, and continue.
                if (line.trim().isEmpty()) {
                    if (builder.length() > 0) {
                        statements.add(builder.toString().trim());
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
     * @param db           DB on which to execute.
     * @param resourcePath Path of the res/assets sql file to execute.
     * @throws java.io.IOException
     */
    public static void executeResource(SQLiteDatabase db, String resourcePath)
            throws IOException {
        List<String> statements = resourceToStatements(resourcePath);

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