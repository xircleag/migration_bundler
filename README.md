# Monkey Butler

![Monkey Butler](logo.jpg)

Monkey Butler is a schema management system for SQLite written in Ruby. It is designed for use in projects that maintain
an identical schema across multiple codebases. It was built to manage the synchronization schema for the iOS and Android 
SDK's on the [Layer](http://layer.com) platform.

Monkey Butler manages a Git repository containing a SQLite schema and an arbitrary number of migrations. The migrations are 
authored in SQL format and platform specific renderings of the schema and migrations are created via code generation.
The current schema and all associated migrations can then be packaged into a release and shipped as an installable package.

## Features

* Manages a Git repository containing a SQLite schema and migrations
* Generates platform specific database management and migration utilities
* Ensures that the current schema and all migrations are valid SQLite
* Packages schema and associated migrations into versioned releases
* Publishes releases for dependency management via CocoaPods and Maven

## Requirements

Monkey Butler requires a modern Ruby runtime (v1.9.x and up) and the following supporting cast:

* [thor](http://whatisthor.com/) - Toolkit for building powerful commandline utilities
* [rugged](https://github.com/libgit2/rugged) - Ruby bindings for libgit2

## Usage

Monkey Butler is a commandline utility available via the `mb` binary. There are a number of standard commandline
switches available that control the defaults and target behavior of a Monkey Butler invocation. You can obtain help directly from the 
application by executing `mb help`.

### Initializing a Project

Creates a new Monkey Butler schema repository at the path specified. Please refer to the documentation below regarding
the repository structure.

`$ mb init [path/to/project]`

### Loading the Schema

Loads the current schema defined in `schema.sql` into a local database named `database.sqlite`.

`$ mb load`

### Creating a Migration

Creates a new migration file at `migrations/[TIMESTAMP]_[NAME].sql`. Please refer to the documentation below about timestamp
and versioning semantics.

`$ mb create [name]`

### Displaying Status

Displays information about the current schema and any unapplied migrations.

`$ mb status`

### Applying Migrations

Applies all pending to a target database by directly executing the SQL migrations.

`$ mb migrate [target version]`

### Generating Implementations

Generates platform specific implementations into `migrations/[migration].m` and `migrations/[migration].java`.

`$ mb generate`

### Validating Schema & Migrations

Validates that the schema loads and all migrations apply forward from a clean database.

`$ mb validate`

### Packaging a Release

Packages a release of the schema by validating the project, generating all implementations, and creating a tag into the
project Git repository.

`$ mb package [version]`

### Pushing a Release

Pushes a release to Git, CocoaPods, and Maven.

`$ mb push [version]`

## Design & Implementation Details

Monkey Butler was designed to deliver the following properties:

1. Provide a simple mechanism for integrating a unified schema into multiple codebases in parallel.
1. Support straightforward bootstrapping of a database with the current schema.
2. Support easy migrations from any previous version of the schema up to the latest by applying an ordered sequence of migrations.
3. Enable reliable, low friction testing of the migration process.
4. Support a heavily branched, multi-developer workflow in which multiple developers are evolving the schema in parallel.

This portion of the document details how Monkey Butler has been implemented to deliver these properties.

### Project Layout

A Monkey Butler project is a simple filesystem layout with version control provided by Git. When a new project is
initialized, it has the following structure:

	.
	├── .gitignore
	├── .monkey_butler.yml
	├── [project-name].sql
	├── [project-name].sqlite
	└── migrations
	    └── <date-created>-create-[project-name].sql

Subsequent commands will create files into this filesystem and perform manipulations on the database. The schema can be branched, merged, and 
released using standard Git techniques.

### Versioning

The client schema is internally versioned using timestamps. Timestamps are used instead of monotonically incrementing integers because they better 
support a branched, multi-developer workflow. The latest version of the overall schema is equal to the timestamp of the most recently applied migration. 
The current schema version of a given database is derivable by examining the `schema_migrations` table, which maintains a record of all migrations that 
have been applied to the database since its creation.

The `schema_migrations` table has the following schema:

```
CREATE TABLE schema_migrations(
	version INTEGER UNIQUE NOT NULL
);

```

The `version` column encodes the date a migration was created. The presence of a given migration version in the table indicates that the migration 
has been applied to the parent database.

#### Computing Origin and Current Version

To compute the "origin version" (the version of the schema at the time the database was created), select the minimum value for the `version` column in the `schema_migrations` table:

`SELECT MIN(version) FROM schema_migrations`

The current version of the database is computable by selecting the maximum value for the `version` column present in the `schema_migrations` table:

`SELECT MAX(version) FROM schema_migrations`

Note that knowing the current version is not sufficient for computing if the database is fully migrated. This is because migrations that were created 
in the past may not yet have been merged, released and applied yet.

#### Computing Unapplied Migrations

In order to compute the set of migrations that have not yet been applied to a given database, one must take the following steps:

1. Compute the origin version of the database
2. Build a collection of the versions of all known migrations in the current build of the code.
3. Build a collection of all migration versions that have already been applied to the database (`SELECT version FROM schema_migrations`);
4. Remove any migrations from the list with a version less than the origin version of the database.
5. Diff the collections of migrations. The set that remains is the set of unapplied migrations.
6. Order the set of unapplied migrations into an array of ascending values and apply them in order from oldest to newest. 

### Migrations

Migrations are authored in pure SQL. A code generation process is used to platform-specific, executable implementation of the migrations in Java and Objective-C
from the source SQL files.

The SQL migration files are named by concatenating a timestamp version with a brief textual description of the database change they introduce to the system. 
This naming convention is of the form "${VERSION_IDENTIFIER}_${MIGRATION_DESCRIPTION_UNDERSCORED}.sql". The `VERSION_IDENTIFIER` is equal to the 
following invocation of the `date` utility (on platforms with GNU coreutils): `date +"%Y%m%d%H%M%S%3N"` This date format includes the year, month, day, hour, minute, 
second and three digits of milliseconds. This ensures that there is very little chance of overlap no matter how many developers are working on the schema, 
while still supporting very straightforward sorting in the database.

An example migration file might be called: `201405125248499_add_unqiue_constraint_to_streams.sql`

The implementation of the generated migration class in Objective-C may look like:

```objc
@interface MBAddUniqueConstraintToStreamsMigration : NSObject <MBMigratable>
@end

@implementation LYR_AddUniqueConstraintToStreamsMigration

+ (NSString *)version
{
	return @"201405125248499";
}

- (BOOL)migrateDatabase:(FMDatabase *)database error:(out NSError *__autoreleasing *)error
{
	// Apply the migration
}

@end
```

Platform specific migrations can also be generated.

## Credits

Blake Watters

- http://github.com/blakewatters
- http://twitter.com/blakewatters
- blakewatters@gmail.com

## License

Monkey Butler is available under the Apache 2 License. See the LICENSE file for more info.
