## v1.2.0

* Introduced `mb drop` for dropping a database.
* Introduced `mb config` for working with config variables.

## v1.1.1

* Include the names of all keyspaces being dumped during a multi-keyspace dump.

## v1.1.0

* Added support for dumping additional keyspaces in Cassandra. Keyspaces are specified via the `cassandra.keyspaces` config setting.

## v1.0.2

* Explicitly require database classes in database targets to avoid `NameError` exception.

## v1.0.1

* Guard against attempts to execute blank Cassandra queries when applying migrations.

## v1.0.0

* Initial public release supporting SQLite and Cassandra.
