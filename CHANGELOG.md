## v1.1.0

* Added support for dumping additional keyspaces in Cassandra. Keyspaces are specified via the `cassandra.keyspaces` config setting.

## v1.0.2

* Explicitly require database classes in database targets to avoid `NameError` exception.

## v1.0.1

* Guard against attempts to execute blank Cassandra queries when applying migrations.

## v1.0.0

* Initial public release supporting SQLite and Cassandra.
