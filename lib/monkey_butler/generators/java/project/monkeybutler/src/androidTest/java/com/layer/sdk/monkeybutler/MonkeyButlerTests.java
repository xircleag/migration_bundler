package com.layer.sdk.monkeybutler;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.test.AndroidTestCase;

import java.util.List;

import static org.fest.assertions.api.Assertions.assertThat;

public class MonkeyButlerTests extends AndroidTestCase {
    private static final String DB_PATH = null;

    private SQLiteDatabase makeDb() {
        SQLiteOpenHelper sqLiteOpenHelper = new SQLiteOpenHelper(getContext(), DB_PATH, null, 1) {
            @Override
            public void onCreate(SQLiteDatabase sqLiteDatabase) {
            }

            @Override
            public void onUpgrade(SQLiteDatabase sqLiteDatabase, int i, int i2) {
            }
        };

        return sqLiteOpenHelper.getWritableDatabase();
    }

    public void testBootstrap() throws Exception {
        SQLiteDatabase db = makeDb();
        final Context appContext = getContext().getApplicationContext();

        final ContentValues values = new ContentValues();
        values.put("version", 100L);

        assertThat(db.insert("schema_migrations", null, values)).isEqualTo(-1);
        MonkeyButler.bootstrap(appContext, db);
        assertThat(db.insert("schema_migrations", null, values)).isNotEqualTo(-1);
    }

    public void testOrigin() throws Exception {
        SQLiteDatabase db = makeDb();
        final Context appContext = getContext().getApplicationContext();

        final ContentValues values1 = new ContentValues();
        values1.put("version", 100L);
        final ContentValues values2 = new ContentValues();
        values2.put("version", 1000L);
        final ContentValues values3 = new ContentValues();
        values3.put("version", 10L);

        MonkeyButler.bootstrap(appContext, db);
        assertThat(db.insert("schema_migrations", null, values1)).isNotEqualTo(-1);
        assertThat(MonkeyButler.getOriginVersion(db)).isEqualTo(100L);
        assertThat(db.insert("schema_migrations", null, values2)).isNotEqualTo(-1);
        assertThat(MonkeyButler.getOriginVersion(db)).isEqualTo(100L);
        assertThat(db.insert("schema_migrations", null, values3)).isNotEqualTo(-1);
        assertThat(MonkeyButler.getOriginVersion(db)).isEqualTo(10L);
    }

    public void testGetAvailableMigrations() throws Exception {
        final Context appContext = getContext().getApplicationContext();

        List<Migration> migrations = MonkeyButler.getAvailableMigrations(appContext);

        assertThat(migrations).hasSize(7);

        assertThat(migrations.get(0).getVersion()).isEqualTo(10L);
        assertThat(migrations.get(1).getVersion()).isEqualTo(1000L);
        assertThat(migrations.get(2).getVersion()).isEqualTo(2000L);
        assertThat(migrations.get(3).getVersion()).isEqualTo(3000L);
        assertThat(migrations.get(4).getVersion()).isEqualTo(4000L);
        assertThat(migrations.get(5).getVersion()).isEqualTo(5000L);
        assertThat(migrations.get(6).getVersion()).isEqualTo(6000L);

        assertThat(migrations.get(0).getDescription()).isEqualTo("Origin");
        assertThat(migrations.get(1).getDescription()).isEqualTo("CreateTableBananas");
        assertThat(migrations.get(2).getDescription()).isEqualTo("InsertYellowGreenIntoBananas");
        assertThat(migrations.get(3).getDescription()).isEqualTo("AlterTableBananasAddRipeness");
        assertThat(migrations.get(4).getDescription()).isEqualTo("UpdateBananaRipeness");
        assertThat(migrations.get(5).getDescription()).isEqualTo("InsertBrownIntoBananas");
        assertThat(migrations.get(6).getDescription()).isEqualTo("DeleteYellowFromBananas");
    }

    public void testApplyMigrations() throws Exception {
        SQLiteDatabase db = makeDb();
        final Context appContext = getContext().getApplicationContext();

        // Verify that 7 migrations were applied and that the new origin is 10
        assertThat(MonkeyButler.applyMigrations(appContext, db)).isEqualTo(7);
        assertThat(MonkeyButler.getOriginVersion(db)).isEqualTo(10);

        // Verify migrated table
        Cursor cursor = db.rawQuery("SELECT type, ripeness FROM bananas ORDER BY type", null);
        assertThat(cursor.getCount()).isEqualTo(2);

        cursor.moveToFirst();
        assertThat(cursor.getString(0)).isEqualTo("brown");
        assertThat(cursor.getString(1)).isEqualTo("extreme");

        cursor.moveToNext();
        assertThat(cursor.getString(0)).isEqualTo("green");
        assertThat(cursor.getString(1)).isEqualTo("low");

        cursor.close();

        // Verify that no migrations remain
        assertThat(MonkeyButler.applyMigrations(appContext, db)).isEqualTo(0);
    }

}
