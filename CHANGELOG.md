## v1.4.0

* Introduces support for [gradle-git-repo-plugin](https://github.com/layerhq/gradle-git-repo-plugin) via the `maven_git` target.
  This plugin provides support for the publication of Maven artifacts hosted in private Git repositories.

## v1.3.3

* Fail if an attempt is made to determine tags with Git < 1.9.x

## v1.3.2

* Various bugfixes for Android/Maven support.

## v1.3.1

* Enhanced support for dumping Cassandra columns.

## v1.3.0

* Added support for dumping arbitrary sets of tables.
* Renamed project to Migration Bundler.

## v1.2.5

* Fix bug in Maven push when publishing point releases.

## v1.2.4

* Fix bug in Maven generate when creating point releases.

## v1.2.3

* Force generate CocoaPods specs by default.

## v1.2.2

* Fix accidental prepending of `create_` to new migraiton names.

## v1.2.1

* Fix double dumping of the default keyspace when using multiple Cassandra keyspaces.

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
